use super::datetime;
use super::message::{
    ChangePasswordInfo,
    LoginInfo,
};
use super::user::{
    ClientSideUser,
    Session,
    User,
    UserLevel,
};
use crate::employee::{
    Employee,
    Name,
    NewEmployee,
};
use crate::schema::{
    employees,
    sessions,
    settings,
    shifts,
    users,
};
use crate::settings::{
    NewSettings,
    Settings,
};
use crate::shift::{
    NewShift,
    Shift,
};
use crate::user::NewSession;
use actix::prelude::*;
use crypto::pbkdf2 as crypt;
use diesel::prelude::*;
use diesel::r2d2::{
    ConnectionManager,
    Pool,
};
use serde::{
    Deserialize,
    Serialize,
};
use std::fmt::{
    Debug,
    Formatter,
};
use std::result::Result;

type Token = String;

pub enum Messages {
    Login(LoginInfo),
    Logout(Token),
    ChangePassword(ChangePasswordInfo),
    GetSettings(Token),
    AddSettings(Token, NewSettings),
    UpdateSettings(Token, Settings),
    GetEmployees(Token),
    GetEmployee(Token, Name),
    AddEmployee(Token, NewEmployee),
    UpdateEmployee(Token, Employee),
    RemoveEmployee(Token, Employee),
    GetShifts(Token, Employee),
    AddShift(Token, NewShift),
    UpdateShift(Token, Shift),
    RemoveShift(Token, Shift),
}

impl Message for Messages {
    type Result = Result<Results, Error>;
}

#[derive(Serialize, Deserialize, Debug)]
pub struct SettingsVecRoot {
    pub settings: Vec<Settings>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct EmployeesVecRoot {
    pub employees: Vec<Employee>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct ShiftsVecRoot {
    pub shifts: Vec<Shift>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct TokenRoot {
    pub token: String,
}

pub enum Results {
    GetSession(TokenRoot),
    GetUser(ClientSideUser),
    GetSettingsVec(SettingsVecRoot),
    GetSettings(Settings),
    GetEmployeesVec(EmployeesVecRoot),
    GetEmployee(Employee),
    GetShiftsVec(ShiftsVecRoot),
    GetShift(Shift),
    Nothing,
}

impl Handler<Messages> for DbExecutor {
    type Result = Result<Results, Error>;

    fn handle(
        &mut self,
        req: Messages,
        _: &mut Self::Context,
    ) -> Self::Result {
        let conn =
            &self.0.get().map_err(|e| Error::R2(e))?;
        match req {
            Messages::Login(login_info) => {
                let user =
                    user_by_email(conn, &login_info.email)?;
                if crypt::pbkdf2_check(
                    &login_info.password,
                    &user.password_hash,
                )
                .is_ok()
                {
                    println!("Password matches!");
                    let session_length = match user.level {
                        UserLevel::Read => 24,
                        _ => 1,
                    };
                    diesel::insert_into(sessions::table)
                        .values(NewSession::new(
                            user.id,
                            datetime::now_plus_hours(
                                session_length,
                            ),
                        ))
                        .get_result::<Session>(conn)
                        .map(|session| {
                            Results::GetSession(TokenRoot {
                                token: session.token,
                            })
                        })
                        .map_err(|dsl_err| {
                            Error::Dsl(dsl_err)
                        })
                } else {
                    println!("Password does not match!");
                    Err(Error::InvalidPassword)
                }
            }
            Messages::Logout(token) => {
                println!("Logout DB message");
                match check_token(&token, conn) {
                    Ok(_) => {
                        println!(
                            "Token to be deleted found"
                        );
                        let delete_result = diesel::delete(
                            sessions::table.filter(
                                sessions::token.eq(token),
                            ),
                        )
                        .execute(conn);
                        match delete_result {
                            Ok(n) => {
                                println!(
                                    "{} tokens deleted",
                                    n
                                )
                            }
                            Err(e) => {
                                eprintln!("Error: {:?}", e)
                            }
                        };
                        Ok(Results::Nothing)
                    }
                    Err(token_err) => Err(token_err),
                }
            }
            Messages::ChangePassword(
                change_password_info,
            ) => {
                let user = user_by_email(
                    conn,
                    &change_password_info.login_info.email,
                )?;
                match crypt::pbkdf2_check(
                    &change_password_info
                        .login_info
                        .password,
                    &user.password_hash,
                )
                .is_ok()
                {
                    true => {
                        let new_hash =
                            crypt::pbkdf2_simple(
                                &change_password_info
                                    .new_password,
                                1,
                            )
                            .map_err(|hash_err| {
                                Error::Misc(format!(
                                    "Hash error: {:?}",
                                    hash_err
                                ))
                            })?;
                        match diesel::update(&user)
                            .set(
                                users::password_hash
                                    .eq(new_hash),
                            )
                            .execute(conn)
                        {
                            Ok(1) => Ok(Results::Nothing),
                            Ok(_) => {
                                Err(Error::Misc(
                                    String::from(
                                        "Updated the wrong number of password hashes! DB corruption may have occurred.",
                                    ),
                                ))
                            }
                            Err(e) => Err(Error::Dsl(e)),
                        }
                    }
                    false => Err(Error::InvalidPassword),
                }
            }
            Messages::GetSettings(token) => {
                let user = check_token(&token, conn)?;
                settings::table
                    .filter(settings::user_id.eq(user.id))
                    .load::<Settings>(conn)
                    .map(|settings_vec| {
                        Results::GetSettingsVec(
                            SettingsVecRoot {
                                settings: settings_vec,
                            },
                        )
                    })
                    .map_err(|err| Error::Dsl(err))
            }
            Messages::AddSettings(token, new_settings) => {
                let user = check_token(&token, conn)?;
                let new_settings = NewSettings {
                    user_id: user.id,
                    ..new_settings
                };
                diesel::insert_into(settings::table)
                    .values(new_settings)
                    .get_result(conn)
                    .map(|added| {
                        Results::GetSettings(added)
                    })
                    .map_err(|err| Error::Dsl(err))
            }
            Messages::UpdateSettings(token, updated) => {
                let user = check_token(&token, conn)?;
                match_ids(user.id, updated.user_id)?;
                diesel::update(&updated.clone())
                    .set(updated)
                    .get_result(conn)
                    .map(|res| Results::GetSettings(res))
                    .map_err(|err| Error::Dsl(err))
            }
            Messages::GetEmployees(token) => {
                let _ = check_token(&token, conn)?;
                employees::table
                    .load::<Employee>(conn)
                    .map(|emps_vec| {
                        Results::GetEmployeesVec(
                            EmployeesVecRoot {
                                employees: emps_vec,
                            },
                        )
                    })
                    .map_err(|err| Error::Dsl(err))
            }
            Messages::GetEmployee(token, name) => {
                let _ = check_token(&token, conn)?;
                employees::table
                    .filter(employees::first.eq(name.first))
                    .filter(employees::last.eq(name.last))
                    .first::<Employee>(conn)
                    .map(|emp| Results::GetEmployee(emp))
                    .map_err(|err| Error::Dsl(err))
            }
            Messages::AddEmployee(token, new_employee) => {
                let user = check_token(&token, conn)?;
                match user.level {
                    UserLevel::Read => {
                        Err(Error::Unauthorized)
                    }
                    _ => {
                        diesel::insert_into(
                            employees::table,
                        )
                        .values(new_employee)
                        .get_result(conn)
                        .map(|emp| {
                            Results::GetEmployee(emp)
                        })
                        .map_err(|err| Error::Dsl(err))
                    }
                }
            }
            Messages::UpdateEmployee(
                token,
                updated_employee,
            ) => {
                let user = check_token(&token, conn)?;
                match user.level {
                    UserLevel::Read => {
                        Err(Error::Unauthorized)
                    }
                    _ => {
                        diesel::update(
                            &updated_employee.clone(),
                        )
                        .set((
                            employees::first.eq(
                                updated_employee.name.first,
                            ),
                            employees::last.eq(
                                updated_employee.name.last,
                            ),
                            employees::phone_number
                                .eq(updated_employee
                                    .phone_number),
                        ))
                        .get_result(conn)
                        .map(|res| {
                            Results::GetEmployee(res)
                        })
                        .map_err(|err| Error::Dsl(err))
                    }
                }
            }
            Messages::RemoveEmployee(token, employee) => {
                let user = check_token(&token, conn)?;
                match user.level {
                    UserLevel::Read => {
                        Err(Error::Unauthorized)
                    }
                    _ => {
                        diesel::delete(&employee.clone())
                            .execute(conn)
                            .map(|_count| Results::Nothing)
                            .map_err(|err| Error::Dsl(err))
                    }
                }
            }
            Messages::GetShifts(token, employee) => {
                let _ = check_token(&token, conn)?;
                shifts::table
                    .filter(
                        shifts::employee_id.eq(employee.id),
                    )
                    .load::<Shift>(conn)
                    .map(|res| {
                        Results::GetShiftsVec(
                            ShiftsVecRoot { shifts: res },
                        )
                    })
                    .map_err(|err| Error::Dsl(err))
            }
            Messages::AddShift(token, new_shift) => {
                let user = check_token(&token, conn)?;
                match_ids(user.id, new_shift.user_id)?;
                match user.level {
                    UserLevel::Read => {
                        Err(Error::Unauthorized)
                    }
                    _ => {
                        diesel::insert_into(shifts::table)
                            .values(new_shift)
                            .get_result(conn)
                            .map(|added| {
                                Results::GetShift(added)
                            })
                            .map_err(|err| Error::Dsl(err))
                    }
                }
            }
            Messages::UpdateShift(token, shift) => {
                let user = check_token(&token, conn)?;
                match_ids(user.id, shift.user_id)?;
                match user.level {
                    UserLevel::Read => {
                        Err(Error::Unauthorized)
                    }
                    _ => {
                        diesel::update(&shift.clone())
                            .set((
                                shifts::employee_id
                                    .eq(shift.employee_id),
                                shifts::year.eq(shift.year),
                                shifts::month
                                    .eq(shift.month),
                                shifts::day.eq(shift.day),
                                shifts::hour.eq(shift.hour),
                                shifts::minute
                                    .eq(shift.minute),
                                shifts::hours
                                    .eq(shift.hours),
                                shifts::minutes
                                    .eq(shift.minutes),
                                shifts::shift_repeat
                                    .eq(shift.shift_repeat),
                                shifts::every_x
                                    .eq(shift.every_x),
                            ))
                            .get_result(conn)
                            .map(|updated| {
                                Results::GetShift(updated)
                            })
                            .map_err(|err| Error::Dsl(err))
                    }
                }
            }
            Messages::RemoveShift(token, shift) => {
                let user = check_token(&token, conn)?;
                match_ids(user.id, shift.user_id)?;
                match user.level {
                    UserLevel::Read => {
                        Err(Error::Unauthorized)
                    }
                    _ => {
                        diesel::delete(&shift)
                            .execute(conn)
                            .map(|_count| Results::Nothing)
                            .map_err(|err| Error::Dsl(err))
                    }
                }
            }
        }
    }
}

fn user_by_email(
    conn: &PgConnection,
    email: &str,
) -> Result<User, Error> {
    users::table
        .filter(users::email.eq(email))
        .first::<User>(conn)
        .map_err(|dsl_err| Error::Dsl(dsl_err))
}

fn match_ids(lhs: i32, rhs: i32) -> Result<(), Error> {
    if lhs == rhs {
        Ok(())
    } else {
        Err(Error::IdentityMismatch)
    }
}

fn check_token(
    token: &str,
    conn: &PgConnection,
) -> std::result::Result<User, Error> {
    use crate::schema::sessions;
    match sessions::table
        .filter(sessions::token.eq(token))
        .first::<Session>(conn)
    {
        Ok(session) => {
            println!("Session found");
            let now = datetime::now();
            let expires_at = session.expires();
            match expires_at.cmp(&now) {
                std::cmp::Ordering::Greater => {
                    println!("Token not expired");
                    users::table
                        .filter(
                            users::id.eq(session.user_id),
                        )
                        .first::<User>(conn)
                        .map(|user| {println!("User associated with token: {:?}", user); user})
                        .map_err(|dsl_err| {
                            Error::Dsl(dsl_err)
                        })
                }
                _ => {
                    println!("Token expired!");
                    Err(Error::TokenExpired)
                }
            }
        }
        Err(_) => {
            println!("Token not found!");
            Err(Error::TokenNotFound)
        }
    }
}

pub enum Error {
    Dsl(diesel::result::Error),
    R2(r2d2::Error),
    InvalidPassword,
    UserExists,
    TokenExpired,
    TokenNotFound,
    Unauthorized,
    IdentityMismatch,
    Misc(String),
}

impl Debug for Error {
    fn fmt(&self, f: &mut Formatter) -> std::fmt::Result {
        match self {
            Error::Dsl(d) => d.fmt(f),
            Error::R2(r) => r.fmt(f),
            Error::InvalidPassword => {
                write!(f, "Incorrect password was entered!")
            }
            Error::UserExists => {
                write!(
                    f,
                    "A user with that email already exists!"
                )
            }
            Error::TokenExpired => {
                write!(f, "The token is expired!")
            }
            Error::TokenNotFound => {
                write!(
                    f,
                    "Token not found, unauthorized access!"
                )
            }
            Error::Unauthorized => {
                write!(f, "Unauthorized request!")
            }
            Error::IdentityMismatch => {
                write!(f, "Identity was not expected")
            }
            Error::Misc(e) => write!(f, "Misc: {}", e),
        }
    }
}

impl Into<actix_web::Error> for Error {
    fn into(self) -> actix_web::Error {
        match self {
            err => {
                actix_web::error::ErrorInternalServerError(
                    format!("{:?}", err),
                )
            }
        }
    }
}

pub struct DbExecutor(
    pub Pool<ConnectionManager<PgConnection>>,
);

impl Actor for DbExecutor {
    type Context = SyncContext<Self>;
}
