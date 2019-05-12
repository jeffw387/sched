use super::datetime;
use super::message::{
    ChangePasswordInfo,
    LoginInfo,
};
use crate::employee::{
    ClientSideEmployee,
    Employee,
    EmployeeLevel,
    NewEmployee,
    NewSession,
    Session,
};
use crate::schema::{
    employees,
    per_employee_settings,
    sessions,
    settings,
    shifts,
    vacations,
};
use crate::settings::{
    CombinedSettings,
    HourFormat,
    LastNameStyle,
    NewPerEmployeeSettings,
    NewSettings,
    PerEmployeeSettings,
    Settings,
    ViewType,
};
use crate::shift::{
    NewShift,
    NewVacation,
    Shift,
    Vacation,
};
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
    ChangePassword(Token, ChangePasswordInfo),
    GetSettings(Token),
    AddSettings(Token, NewSettings),
    CopySettings(Token, CombinedSettings),
    SetDefaultSettings(Token, Settings),
    DefaultSettings(Token),
    UpdateSettings(Token, Settings),
    RemoveSettings(Token, Settings),
    AddEmployeeSettings(Token, NewPerEmployeeSettings),
    UpdateEmployeeSettings(Token, PerEmployeeSettings),
    GetEmployees(Token),
    GetCurrentEmployee(Token),
    AddEmployee(Token, ClientSideEmployee),
    UpdateEmployee(Token, ClientSideEmployee),
    RemoveEmployee(Token, ClientSideEmployee),
    GetShifts(Token),
    AddShift(Token, NewShift),
    UpdateShift(Token, Shift),
    RemoveShift(Token, Shift),
    GetVacations(Token),
    AddVacation(Token, NewVacation),
    UpdateVacation(Token, Vacation),
    UpdateVacationApproval(Token, Vacation),
    RemoveVacation(Token, Vacation),
}

impl Message for Messages {
    type Result = Result<Results, Error>;
}

#[derive(Serialize, Deserialize, Debug)]
pub struct JsonObject<T> {
    pub contents: T,
}

impl<T> JsonObject<T> {
    pub fn new(t: T) -> Self {
        Self { contents: t }
    }
}

pub enum Results {
    GetSession(JsonObject<String>),
    GetEmployee(ClientSideEmployee),
    GetCombinedSettings(JsonObject<Vec<CombinedSettings>>),
    GetSettings(Settings),
    GetSettingsID(JsonObject<Option<i32>>),
    GetEmployeesVec(JsonObject<Vec<ClientSideEmployee>>),
    GetShiftsVec(JsonObject<Vec<Shift>>),
    GetEmployeeShifts(JsonObject<Vec<Shift>>),
    GetShift(Shift),
    GetVacations(JsonObject<Vec<Vacation>>),
    GetVacation(Vacation),
    Nothing,
}

impl Handler<Messages> for DbExecutor {
    type Result = Result<Results, Error>;

    fn handle(
        &mut self,
        req: Messages,
        _: &mut Self::Context,
    ) -> Self::Result {
        let conn = &self.0.get().map_err(Error::R2)?;
        match req {
            Messages::Login(login_info) => {
                let owner = employee_by_email(
                    conn,
                    &login_info.email,
                )?;
                if crypt::pbkdf2_check(
                    &login_info.password,
                    &owner.password_hash,
                )
                .is_ok()
                {
                    println!("Password matches!");
                    let session_length = 24;
                    diesel::insert_into(sessions::table)
                        .values(NewSession::new(
                            owner.id,
                            datetime::now_plus_hours(
                                session_length,
                            ),
                        ))
                        .get_result::<Session>(conn)
                        .map(|session| {
                            Results::GetSession(
                                JsonObject::new(
                                    session.token,
                                ),
                            )
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
                token,
                change_password_info,
            ) => {
                let owner = check_token(&token, conn)?;
                if crypt::pbkdf2_check(
                    &change_password_info
                        .old_password,
                    &owner.password_hash,
                )
                .is_ok()
                {
                    let new_hash = crypt::pbkdf2_simple(
                        &change_password_info.new_password,
                        1,
                    )
                    .map_err(|hash_err| {
                        Error::Misc(format!(
                            "Hash error: {:?}",
                            hash_err
                        ))
                    })?;
                    match diesel::update(&owner)
                        .set(
                            employees::password_hash
                                .eq(new_hash),
                        )
                        .execute(conn)
                    {
                        Ok(1) => Ok(Results::Nothing),
                        Ok(_) => {
                            Err(Error::Misc(String::from(
                                "Updated the wrong number of password hashes! DB corruption may have occurred.",
                            )))
                        }
                        Err(e) => Err(Error::Dsl(e)),
                    }
                } else {
                    Err(Error::InvalidPassword)
                }
            }
            Messages::GetSettings(token) => {
                println!("Messages::GetSettings");
                let owner = check_token(&token, conn)?;
                let employee_settings = settings::table
                    .filter(
                        settings::employee_id.eq(owner.id),
                    )
                    .load::<Settings>(conn)
                    .map_err(Error::Dsl)?;
                let per_employee =
                    per_employee_settings::table
                        .load::<PerEmployeeSettings>(conn)
                        .map_err(Error::Dsl)?;
                let combined_settings =
                    employee_settings.iter().map(|u_s| {
                        let mut combined =
                            CombinedSettings {
                                settings: u_s.clone(),
                                per_employee: vec![],
                            };
                        for p_e in per_employee.clone() {
                            if u_s.id == p_e.settings_id {
                                combined
                                    .per_employee
                                    .push(p_e);
                            }
                        }
                        combined
                    });
                Ok(Results::GetCombinedSettings(
                    JsonObject::new(
                        combined_settings.collect(),
                    ),
                ))
            }
            Messages::AddSettings(token, new_settings) => {
                println!("Messages::AddSettings");
                let owner = check_token(&token, conn)?;
                let new_settings = NewSettings {
                    employee_id: owner.id,
                    ..new_settings
                };
                diesel::insert_into(settings::table)
                    .values(new_settings)
                    .get_result(conn)
                    .map(Results::GetSettings)
                    .map_err(Error::Dsl)
            }
            Messages::CopySettings(
                token,
                combined_settings,
            ) => {
                println!("Messages::CopySettings");
                let _ = check_token(&token, conn)?;
                let new_settings: NewSettings =
                    combined_settings
                        .settings
                        .clone()
                        .into();
                diesel::insert_into(settings::table)
                    .values(new_settings)
                    .get_result(conn)
                    .map_err(Error::Dsl)
                    .map(|inserted_settings: Settings| {
                        let new_per_employees: Vec<NewPerEmployeeSettings> =
                            combined_settings.per_employee
                                .iter()
                                .map(|p_e| {
                                    let updated_p_e = PerEmployeeSettings { settings_id: inserted_settings.id, ..p_e.clone() };
                                    updated_p_e.into()
                                }).collect();
                        let _ = diesel::insert_into(per_employee_settings::table)
                            .values(new_per_employees)
                            .execute(conn)
                            .map_err(Error::Dsl);
                    })?;
                Ok(Results::Nothing)
            }
            Messages::SetDefaultSettings(
                token,
                settings,
            ) => {
                println!("SetDefaultSettings: start");
                let owner = check_token(&token, conn)?;
                let _ = diesel::update(&owner)
                    .set(
                        employees::startup_settings
                            .eq(settings.id),
                    )
                    .execute(conn)
                    .map_err(|err| {
                        eprintln!("Error: {:?}", err);
                        Error::Dsl(err)
                    })?;
                Ok(Results::Nothing)
            }
            Messages::DefaultSettings(token) => {
                let owner = check_token(&token, conn)?;
                println!("Messages::DefaultSettings");
                Ok(Results::GetSettingsID(JsonObject::new(
                    owner.startup_settings,
                )))
            }
            Messages::UpdateSettings(token, updated) => {
                println!("Messages::UpdateSettings");
                let _ = check_token(&token, conn)?;
                diesel::update(&updated.clone())
                    .set(updated)
                    .get_result(conn)
                    .map(Results::GetSettings)
                    .map_err(Error::Dsl)
            }
            Messages::RemoveSettings(token, settings) => {
                let owner = check_token(&token, conn)?;
                let employee_settings = settings::table
                    .filter(
                        settings::employee_id.eq(owner.id),
                    )
                    .load::<Settings>(conn)
                    .map_err(Error::Dsl)?;
                if employee_settings.len() > 1 {
                    let _ = diesel::delete(&settings)
                        .execute(conn)
                        .map_err(Error::Dsl)?;
                    let new_default = settings::table
                        .filter(
                            settings::employee_id
                                .eq(owner.id),
                        )
                        .first::<Settings>(conn)
                        .map_err(Error::Dsl)?;
                    let _ = diesel::update(&owner.clone())
                        .set(
                            employees::startup_settings
                                .eq(new_default.id),
                        )
                        .execute(conn)
                        .map_err(Error::Dsl)?;
                }
                Ok(Results::Nothing)
            }
            Messages::AddEmployeeSettings(
                token,
                new_settings,
            ) => {
                println!("Messages::AddEmployeeSettings");
                let _ = check_token(&token, conn)?;
                diesel::insert_into(
                    per_employee_settings::table,
                )
                .values(new_settings)
                .execute(conn)
                .map_err(Error::Dsl)
                .map(|_| Results::Nothing)
            }
            Messages::UpdateEmployeeSettings(
                token,
                settings,
            ) => {
                println!(
                    "Messages::UpdateEmployeeSettings"
                );
                let _ = check_token(&token, conn)?;
                diesel::update(&settings.clone())
                    .set(settings)
                    .execute(conn)
                    .map(|_| Results::Nothing)
                    .map_err(Error::Dsl)
            }
            Messages::GetEmployees(token) => {
                println!("Messages::GetEmployees");
                let _ = check_token(&token, conn)?;
                employees::table
                    .load::<Employee>(conn)
                    .map(|emps_vec| {
                        let cs_emps: Vec<
                            ClientSideEmployee,
                        > = emps_vec
                            .iter()
                            .map(|emp| emp.clone().into())
                            .collect();
                        Results::GetEmployeesVec(
                            JsonObject::new(cs_emps),
                        )
                    })
                    .map_err(Error::Dsl)
            }
            Messages::GetCurrentEmployee(token) => {
                println!("Messages::GetCurrentEmployee");
                check_token(&token, conn)
                    .map(|e| Results::GetEmployee(e.into()))
            }
            Messages::AddEmployee(
                token,
                new_client_employee,
            ) => {
                println!("Messages::AddEmployee");
                let owner = check_token(&token, conn)?;
                let login_info = LoginInfo {
                    email: String::new(),
                    password: String::new(),
                };

                let new_employee = NewEmployee::new(
                    login_info,
                    None,
                    EmployeeLevel::Read,
                    new_client_employee.name,
                    new_client_employee.phone_number,
                );
                match owner.level {
                    EmployeeLevel::Read => {
                        Err(Error::Unauthorized)
                    }
                    _ => {
                        let inserted_employee =
                            diesel::insert_into(
                                employees::table,
                            )
                            .values(new_employee)
                            .get_result::<Employee>(conn)
                            .map_err(Error::Dsl)?;

                        let new_settings = NewSettings {
                            employee_id: inserted_employee
                                .id,
                            name: String::from("Default"),
                            view_type: ViewType::Month,
                            hour_format: HourFormat::Hour12,
                            last_name_style:
                                LastNameStyle::FirstInitial,
                            view_year: 2019,
                            view_month: 4,
                            view_day: 29,
                            view_employees: vec![],
                            show_minutes: true,
                            show_shifts: true,
                            show_vacations: false
                        };

                        let inserted_settings =
                            diesel::insert_into(
                                settings::table,
                            )
                            .values(new_settings)
                            .get_result::<Settings>(conn)
                            .map_err(Error::Dsl)?;

                        diesel::update(&inserted_employee)
                            .set(
                                employees::startup_settings
                                    .eq(inserted_settings
                                        .id),
                            )
                            .get_result::<Employee>(conn)
                            .map(|e| {
                                Results::GetEmployee(
                                    e.into(),
                                )
                            })
                            .map_err(Error::Dsl)
                    }
                }
            }
            Messages::UpdateEmployee(
                token,
                updated_employee,
            ) => {
                println!("Messages::UpdateEmployee");
                let owner = check_token(&token, conn)?;
                match owner.level {
                    EmployeeLevel::Read => {
                        Err(Error::Unauthorized)
                    }
                    _ => diesel::update(employees::table)
                        .filter(
                            employees::id
                                .eq(updated_employee.id),
                        )
                        .set((
                            employees::email
                                .eq(updated_employee.email),
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
                        .execute(conn)
                        .map(|_| Results::Nothing)
                        .map_err(Error::Dsl),
                }
            }
            Messages::RemoveEmployee(token, employee) => {
                println!("Messages::RemoveEmployee");
                let owner = check_token(&token, conn)?;
                match owner.level {
                    EmployeeLevel::Read => {
                        Err(Error::Unauthorized)
                    }
                    _ => {
                        diesel::delete(employees::table)
                            .filter(
                                employees::id
                                    .eq(employee.id),
                            )
                            .execute(conn)
                            .map(|_count| Results::Nothing)
                            .map_err(Error::Dsl)
                    }
                }
            }
            Messages::GetShifts(token) => {
                println!("Messages::GetShifts");
                let _ = check_token(&token, conn)?;
                shifts::table
                    .load::<Shift>(conn)
                    .map(|res| {
                        Results::GetShiftsVec(
                            JsonObject::new(res),
                        )
                    })
                    .map_err(Error::Dsl)
            }
            Messages::AddShift(token, new_shift) => {
                println!("Messages::AddShift");
                let owner = check_token(&token, conn)?;
                let new_shift = NewShift {
                    supervisor_id: owner.id,
                    ..new_shift
                };
                match owner.level {
                    EmployeeLevel::Read => {
                        Err(Error::Unauthorized)
                    }
                    _ => {
                        diesel::insert_into(shifts::table)
                            .values(new_shift)
                            .get_result(conn)
                            .map(Results::GetShift)
                            .map_err(Error::Dsl)
                    }
                }
            }
            Messages::UpdateShift(token, shift) => {
                println!("Messages::UpdateShift");
                let owner = check_token(&token, conn)?;
                match_ids(owner.id, shift.supervisor_id)?;
                match owner.level {
                    EmployeeLevel::Read => {
                        Err(Error::Unauthorized)
                    }
                    _ => diesel::update(&shift.clone())
                        .set(shift.clone())
                        .get_result(conn)
                        .map(Results::GetShift)
                        .map_err(Error::Dsl),
                }
            }
            Messages::RemoveShift(token, shift) => {
                println!("Messages::RemoveShift");
                let owner = check_token(&token, conn)?;
                match_ids(owner.id, shift.supervisor_id)?;
                match owner.level {
                    EmployeeLevel::Read => {
                        Err(Error::Unauthorized)
                    }
                    _ => {
                        diesel::delete(&shift)
                            .execute(conn)
                            .map(|_| Results::Nothing)
                            .map_err(Error::Dsl)
                    }
                }
            }

            Messages::GetVacations(token) => {
                println!("Messages::GetVacations");
                let _ = check_token(&token, conn)?;
                vacations::table
                    .load::<Vacation>(conn)
                    .map(|res| {
                        Results::GetVacations(
                            JsonObject::new(res),
                        )
                    })
                    .map_err(|err| {
                        eprintln!("Error: {:?}", err);
                        Error::Dsl(err)
                    })
            }
            Messages::AddVacation(token, new_vacation) => {
                println!("Messages::AddVacation");
                let _ = check_token(&token, conn)?;
                diesel::insert_into(vacations::table)
                    .values(new_vacation)
                    .get_result(conn)
                    .map(Results::GetVacation)
                    .map_err(Error::Dsl)
            }
            Messages::UpdateVacation(token, vacation) => {
                println!("Messages::UpdateVacation");
                let current_employee =
                    check_token(&token, conn)?;
                match_ids(
                    current_employee.id,
                    vacation.employee_id,
                )?;

                diesel::update(&vacation.clone())
                    .set(vacation.clone())
                    .get_result(conn)
                    .map(Results::GetVacation)
                    .map_err(Error::Dsl)
            }
            Messages::UpdateVacationApproval(token, vacation) => {
                println!("Messages::UpdateVacation");
                let supervisor =
                    check_token(&token, conn)?;
                match_ids(
                    supervisor.id,
                    vacation.supervisor_id.unwrap_or(-1),
                )?;

                diesel::update(&vacation.clone())
                    .set(vacation.clone())
                    .get_result(conn)
                    .map(Results::GetVacation)
                    .map_err(Error::Dsl)
            }
            Messages::RemoveVacation(token, vacation) => {
                println!("Messages::RemoveVacation");
                let current_employee =
                    check_token(&token, conn)?;
                match_ids(
                    current_employee.id,
                    vacation.employee_id,
                )?;

                diesel::delete(&vacation)
                    .execute(conn)
                    .map(|_| Results::Nothing)
                    .map_err(Error::Dsl)
            }
        }
    }
}

fn employee_by_email(
    conn: &PgConnection,
    email: &str,
) -> Result<Employee, Error> {
    employees::table
        .filter(employees::email.eq(email))
        .first::<Employee>(conn)
        .map_err(Error::Dsl)
}

fn match_ids(lhs: i32, rhs: i32) -> Result<(), Error> {
    if lhs == rhs {
        Ok(())
    } else {
        Err(Error::IdentityMismatch)
    }
}

fn debug_print<T: std::fmt::Debug>(t: T) -> T {
    println!("{:#?}", t);
    t
}

fn check_token(
    token: &str,
    conn: &PgConnection,
) -> std::result::Result<Employee, Error> {
    match sessions::table
        .filter(sessions::token.eq(token))
        .first::<Session>(conn)
    {
        Ok(session) => {
            let now = datetime::now();
            let expires_at = session.expires();
            match expires_at.cmp(&now) {
                std::cmp::Ordering::Greater => {
                    employees::table
                        .filter(
                            employees::id
                                .eq(session.employee_id),
                        )
                        .first::<Employee>(conn)
                        .map_err(Error::Dsl)
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
    EmployeeExists,
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
            Error::EmployeeExists => {
                write!(
                    f,
                    "A owner with that email already exists!"
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
