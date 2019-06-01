use super::message::{
    ChangePasswordInfo,
    LoginInfo,
};
use crate::config::{
    CombinedConfig,
    Config,
    EmployeeColor,
    HourFormat,
    LastNameStyle,
    NewConfig,
    NewPerEmployeeConfig,
    PerEmployeeConfig,
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
    configs,
    employees,
    per_employee_configs,
    sessions,
    shift_exceptions,
    shifts,
    vacations,
};
use crate::shift::{
    NewShift,
    NewShiftException,
    NewVacation,
    Shift,
    ShiftException,
    Vacation,
};
use actix_web::web;
use chrono::Utc;
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
use std::ops::Deref;
use std::result::Result;

type Token = String;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct JsonObject<T: Clone> {
    pub contents: T,
}

impl<T: Clone> JsonObject<T> {
    pub fn new(t: T) -> Self {
        Self { contents: t }
    }
}

pub type PgPool = Pool<ConnectionManager<PgConnection>>;

pub fn login(
    pool: web::Data<PgPool>,
    login_info: LoginInfo,
) -> Result<(ClientSideEmployee, String), Error> {
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let owner = employee_by_email(pool, &login_info.email)?;

    match crypt::pbkdf2_check(
        &login_info.password,
        &owner.password_hash,
    ) {
        Ok(matches) => {
            if matches {
                println!("Password matches!");
                let session_length = 24;
                diesel::insert_into(sessions::table)
                    .values(NewSession::new(
                        owner.id,
                        Utc::now()
                            + chrono::Duration::hours(
                                session_length,
                            ),
                    ))
                    .get_result::<Session>(conn)
                    .map(|session| {
                        (owner.into(), session.token)
                    })
                    .map_err(|dsl_err| Error::Dsl(dsl_err))
            } else {
                println!("Password does not match!");
                Err(Error::InvalidPassword)
            }
        }
        Err(e) => Err(Error::Misc(String::from(e))),
    }
}

pub fn update_employee_color(
    pool: web::Data<PgPool>,
    token: Token,
    color: EmployeeColor,
) -> Result<(), Error> {
    println!("Messages::UpdateEmployeeColor");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let user = check_token(&token, pool)?;
    diesel::update(&user)
        .set(employees::default_color.eq(color))
        .execute(conn)
        .map(|_| ())
        .map_err(Error::Dsl)
}

pub fn update_employee_phone_number(
    pool: web::Data<PgPool>,
    token: Token,
    phone_number: String,
) -> Result<(), Error> {
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    println!("Messages::UpdateEmployeePhoneNumber");
    let user = check_token(&token, pool)?;
    diesel::update(&user)
        .set(employees::phone_number.eq(phone_number))
        .execute(conn)
        .map(|_| ())
        .map_err(Error::Dsl)
}

pub fn logout(
    pool: web::Data<PgPool>,
    token: Token,
) -> Result<(), Error> {
    println!("Logout DB message");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    match check_token(&token, pool) {
        Ok(_) => {
            println!("Token to be deleted found");
            let delete_result = diesel::delete(
                sessions::table
                    .filter(sessions::token.eq(token)),
            )
            .execute(conn);
            match delete_result {
                Ok(n) => println!("{} tokens deleted", n),
                Err(e) => eprintln!("Error: {:?}", e),
            };
            Ok(())
        }
        Err(token_err) => Err(token_err),
    }
}

pub fn change_password(
    pool: web::Data<PgPool>,
    token: Token,
    change_password_info: ChangePasswordInfo,
) -> Result<(), Error> {
    println!("Messages::ChangePassword");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let owner = check_token(&token, pool)?;
    match crypt::pbkdf2_check(
        &change_password_info.old_password,
        &owner.password_hash,
    ) {
        Ok(matches) => {
            if matches {
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
                    Ok(_) => Ok(()),
                    Err(e) => Err(Error::Dsl(e)),
                }
            } else {
                eprintln!("Error: Invalid password!");
                Err(Error::InvalidPassword)
            }
        }
        Err(e) => Err(Error::Misc(String::from(e))),
    }
}

pub fn get_configs(
    pool: web::Data<PgPool>,
    token: Token,
) -> Result<JsonObject<Vec<CombinedConfig>>, Error> {
    println!("Messages::GetConfigs");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let owner = check_token(&token, pool)?;
    let employee_config = configs::table
        .filter(configs::employee_id.eq(owner.id))
        .load::<Config>(conn)
        .map_err(Error::Dsl)?;
    let per_employee = per_employee_configs::table
        .load::<PerEmployeeConfig>(conn)
        .map_err(Error::Dsl)?;
    let combined_config =
        employee_config.iter().map(|config| {
            let mut combined = CombinedConfig {
                config: config.clone(),
                per_employee: vec![],
            };
            for p_e in per_employee.clone() {
                if config.id == p_e.config_id {
                    combined.per_employee.push(p_e);
                }
            }
            combined
        });
    Ok(JsonObject::new(combined_config.collect()))
}

pub fn add_config(
    pool: web::Data<PgPool>,
    token: Token,
    new_config: NewConfig,
) -> Result<Config, Error> {
    println!("Messages::AddConfig");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let owner = check_token(&token, pool)?;
    let new_config =
        NewConfig { employee_id: owner.id, ..new_config };
    diesel::insert_into(configs::table)
        .values(new_config)
        .get_result(conn)
        .map_err(Error::Dsl)
}

pub fn copy_config(
    pool: web::Data<PgPool>,
    token: Token,
    combined_config: CombinedConfig,
) -> Result<(), Error> {
    println!("Messages::CopyConfig");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let _ = check_token(&token, pool)?;
    let config = combined_config.config.clone();
    let new_config = NewConfig {
        employee_id: config.employee_id,
        config_name: config.config_name,
        hour_format: config.hour_format,
        last_name_style: config.last_name_style,
        view_date: config.view_date,
        view_employees: config.view_employees,
        show_minutes: config.show_minutes,
        show_shifts: config.show_shifts,
        show_vacations: config.show_vacations,
        show_call_shifts: config.show_call_shifts,
        show_disabled: config.show_disabled,
    };
    diesel::insert_into(configs::table)
        .values(new_config)
        .get_result(conn)
        .map_err(Error::Dsl)
        .map(move |inserted_config: Config| {
            let new_per_employees: Vec<
                NewPerEmployeeConfig,
            > = combined_config
                .per_employee
                .iter()
                .map(move |p_e| {
                    NewPerEmployeeConfig {
                        config_id: inserted_config.id,
                        employee_id: p_e
                            .employee_id
                            .clone(),
                        color: p_e.color.clone(),
                    }
                })
                .collect();
            let _ = diesel::insert_into(
                per_employee_configs::table,
            )
            .values(new_per_employees)
            .execute(conn)
            .map_err(Error::Dsl);
        })?;
    Ok(())
}

pub fn set_active_config(
    pool: web::Data<PgPool>,
    token: Token,
    config: Config,
) -> Result<(), Error> {
    println!("SetDefaultConfig: start");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let owner = check_token(&token, pool)?;
    let _ = diesel::update(&owner)
        .set(employees::active_config.eq(config.id))
        .execute(conn)
        .map_err(|err| {
            eprintln!("Error: {:?}", err);
            Error::Dsl(err)
        })?;
    Ok(())
}

pub fn get_active_config(
    pool: web::Data<PgPool>,
    token: Token,
) -> Result<JsonObject<Option<i32>>, Error> {
    println!("Messages::DefaultConfig");
    let owner = check_token(&token, pool)?;
    Ok(JsonObject::new(owner.active_config))
}

pub fn update_config(
    pool: web::Data<PgPool>,
    token: Token,
    updated: Config,
) -> Result<Config, Error> {
    println!("Messages::UpdateConfig");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let _ = check_token(&token, pool)?;
    diesel::update(&updated.clone())
        .set(updated)
        .get_result(conn)
        .map_err(Error::Dsl)
}

pub fn remove_config(
    pool: web::Data<PgPool>,
    token: Token,
    config: Config,
) -> Result<(), Error> {
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let owner = check_token(&token, pool)?;
    let employee_config = configs::table
        .filter(configs::employee_id.eq(owner.id))
        .load::<Config>(conn)
        .map_err(Error::Dsl)?;
    if employee_config.len() > 1 {
        let _ = diesel::delete(&config)
            .execute(conn)
            .map_err(Error::Dsl)?;
        let new_default = configs::table
            .filter(configs::employee_id.eq(owner.id))
            .first::<Config>(conn)
            .map_err(Error::Dsl)?;
        let _ = diesel::update(&owner.clone())
            .set(
                employees::active_config.eq(new_default.id),
            )
            .execute(conn)
            .map_err(Error::Dsl)?;
    }
    Ok(())
}

pub fn add_employee_config(
    pool: web::Data<PgPool>,
    token: Token,
    new_config: NewPerEmployeeConfig,
) -> Result<(), Error> {
    println!("Messages::AddEmployeeConfig");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let _ = check_token(&token, pool)?;
    diesel::insert_into(per_employee_configs::table)
        .values(new_config)
        .execute(conn)
        .map_err(Error::Dsl)
        .map(|_| ())
}

pub fn update_employee_config(
    pool: web::Data<PgPool>,
    token: Token,
    config: PerEmployeeConfig,
) -> Result<(), Error> {
    println!("Messages::UpdateEmployeeConfig");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let _ = check_token(&token, pool)?;
    diesel::update(&config.clone())
        .set(config)
        .execute(conn)
        .map(|_| ())
        .map_err(Error::Dsl)
}

pub fn get_employees(
    pool: web::Data<PgPool>,
    token: Token,
) -> Result<JsonObject<Vec<ClientSideEmployee>>, Error> {
    println!("Messages::GetEmployees");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let _ = check_token(&token, pool)?;
    employees::table
        .load::<Employee>(conn)
        .map(|emps_vec| {
            let cs_emps: Vec<ClientSideEmployee> = emps_vec
                .iter()
                .map(|emp| emp.clone().into())
                .collect();
            JsonObject::new(cs_emps)
        })
        .map_err(Error::Dsl)
}

pub fn get_current_employee(
    pool: web::Data<PgPool>,
    token: Token,
) -> Result<ClientSideEmployee, Error> {
    println!("Messages::GetCurrentEmployee");
    check_token(&token, pool).map(|e| e.into())
}

pub fn add_employee(
    pool: web::Data<PgPool>,
    token: Token,
    new_client_employee: ClientSideEmployee,
) -> Result<ClientSideEmployee, Error> {
    println!("Messages::AddEmployee");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let owner = check_token(&token, pool)?;
    let login_info = LoginInfo {
        email: String::new(),
        password: String::new(),
    };

    let new_employee = NewEmployee::new(
        login_info,
        None,
        EmployeeLevel::Read,
        new_client_employee.first,
        new_client_employee.last,
        new_client_employee.phone_number,
        EmployeeColor::Green,
    );
    match owner.level {
        EmployeeLevel::Read => Err(Error::Unauthorized),
        _ => {
            let inserted_employee =
                diesel::insert_into(employees::table)
                    .values(new_employee)
                    .get_result::<Employee>(conn)
                    .map_err(Error::Dsl)?;

            let new_config = NewConfig {
                employee_id: inserted_employee.id,
                config_name: String::from("Default"),
                hour_format: HourFormat::H12,
                last_name_style: LastNameStyle::Initial,
                view_date: Utc::now(),
                view_employees: vec![],
                show_minutes: true,
                show_shifts: true,
                show_vacations: false,
                show_call_shifts: false,
                show_disabled: false,
            };

            let inserted_config =
                diesel::insert_into(configs::table)
                    .values(new_config)
                    .get_result::<Config>(conn)
                    .map_err(Error::Dsl)?;

            diesel::update(&inserted_employee)
                .set(
                    employees::active_config
                        .eq(inserted_config.id),
                )
                .get_result::<Employee>(conn)
                .map(|e| e.into())
                .map_err(Error::Dsl)
        }
    }
}
pub fn update_employee(
    pool: web::Data<PgPool>,
    token: Token,
    updated_employee: ClientSideEmployee,
) -> Result<(), Error> {
    println!("Messages::UpdateEmployee");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let owner = check_token(&token, pool)?;
    match owner.level {
        EmployeeLevel::Read => Err(Error::Unauthorized),
        _ => {
            diesel::update(employees::table)
                .filter(
                    employees::id.eq(updated_employee.id),
                )
                .set((
                    employees::email
                        .eq(updated_employee.email),
                    employees::first
                        .eq(updated_employee.first),
                    employees::last
                        .eq(updated_employee.last),
                    employees::phone_number
                        .eq(updated_employee.phone_number),
                    employees::default_color
                        .eq(updated_employee.default_color),
                ))
                .execute(conn)
                .map(|_| ())
                .map_err(Error::Dsl)
        }
    }
}

pub fn remove_employee(
    pool: web::Data<PgPool>,
    token: Token,
    employee: ClientSideEmployee,
) -> Result<(), Error> {
    println!("Messages::RemoveEmployee");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let owner = check_token(&token, pool)?;
    match owner.level {
        EmployeeLevel::Read => Err(Error::Unauthorized),
        _ => {
            diesel::delete(employees::table)
                .filter(employees::id.eq(employee.id))
                .execute(conn)
                .map(|_| ())
                .map_err(Error::Dsl)
        }
    }
}
pub fn get_shifts(
    pool: web::Data<PgPool>,
    token: Token,
) -> Result<JsonObject<Vec<Shift>>, Error> {
    println!("Messages::GetShifts");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let _ = check_token(&token, pool)?;
    shifts::table
        .load::<Shift>(conn)
        .map(|res| JsonObject::new(res))
        .map_err(Error::Dsl)
}

pub fn add_shift(
    pool: web::Data<PgPool>,
    token: Token,
    new_shift: NewShift,
) -> Result<Shift, Error> {
    println!("Messages::AddShift");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let owner = check_token(&token, pool)?;
    let new_shift =
        NewShift { supervisor_id: owner.id, ..new_shift };
    match owner.level {
        EmployeeLevel::Read => Err(Error::Unauthorized),
        _ => {
            diesel::insert_into(shifts::table)
                .values(new_shift)
                .get_result(conn)
                .map_err(Error::Dsl)
        }
    }
}

pub fn update_shift(
    pool: web::Data<PgPool>,
    token: Token,
    shift: Shift,
) -> Result<Shift, Error> {
    println!("Messages::UpdateShift");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let owner = check_token(&token, pool)?;
    match_ids(owner.id, shift.supervisor_id)?;
    match owner.level {
        EmployeeLevel::Read => Err(Error::Unauthorized),
        _ => {
            diesel::update(&shift.clone())
                .set(shift.clone())
                .get_result(conn)
                .map_err(Error::Dsl)
        }
    }
}

pub fn remove_shift(
    pool: web::Data<PgPool>,
    token: Token,
    shift: Shift,
) -> Result<(), Error> {
    println!("Messages::RemoveShift");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let owner = check_token(&token, pool)?;
    match_ids(owner.id, shift.supervisor_id)?;
    match owner.level {
        EmployeeLevel::Read => Err(Error::Unauthorized),
        _ => {
            diesel::delete(&shift)
                .execute(conn)
                .map(|_| ())
                .map_err(Error::Dsl)
        }
    }
}

pub fn get_shift_exceptions(
    pool: web::Data<PgPool>,
    token: Token,
) -> Result<JsonObject<Vec<ShiftException>>, Error> {
    println!("Messages::GetShiftExceptions");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let _ = check_token(&token, pool)?;
    shift_exceptions::table
        .load::<ShiftException>(conn)
        .map(|res| JsonObject::new(res))
        .map_err(Error::Dsl)
}

pub fn add_shift_exception(
    pool: web::Data<PgPool>,
    token: Token,
    new_shift_exception: NewShiftException,
) -> Result<ShiftException, Error> {
    println!("Messages::AddShiftException");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let owner = check_token(&token, pool)?;

    let shift = shifts::table
        .filter(shifts::id.eq(new_shift_exception.shift_id))
        .first::<Shift>(conn)
        .map_err(Error::Dsl)?;

    match_ids(owner.id, shift.supervisor_id)?;

    match owner.level {
        EmployeeLevel::Read => Err(Error::Unauthorized),
        _ => {
            diesel::insert_into(shift_exceptions::table)
                .values(new_shift_exception)
                .get_result(conn)
                .map_err(Error::Dsl)
        }
    }
}

pub fn update_shift_exception(
    pool: web::Data<PgPool>,
    token: Token,
    shift_exception: ShiftException,
) -> Result<ShiftException, Error> {
    println!("Messages::UpdateShiftException");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let owner = check_token(&token, pool)?;

    let shift = shifts::table
        .filter(shifts::id.eq(shift_exception.shift_id))
        .first::<Shift>(conn)
        .map_err(Error::Dsl)?;

    match_ids(owner.id, shift.supervisor_id)?;
    match owner.level {
        EmployeeLevel::Read => Err(Error::Unauthorized),
        _ => {
            diesel::update(&shift_exception.clone())
                .set(shift_exception.clone())
                .get_result(conn)
                .map_err(Error::Dsl)
        }
    }
}

pub fn remove_shift_exception(
    pool: web::Data<PgPool>,
    token: Token,
    shift_exception: ShiftException,
) -> Result<(), Error> {
    println!("Messages::RemoveShiftException");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let owner = check_token(&token, pool)?;
    let shift = shifts::table
        .filter(shifts::id.eq(shift_exception.shift_id))
        .first::<Shift>(conn)
        .map_err(Error::Dsl)?;

    match_ids(owner.id, shift.supervisor_id)?;
    match owner.level {
        EmployeeLevel::Read => Err(Error::Unauthorized),
        _ => {
            diesel::delete(&shift_exception)
                .execute(conn)
                .map(|_| ())
                .map_err(Error::Dsl)
        }
    }
}

pub fn get_vacations(
    pool: web::Data<PgPool>,
    token: Token,
) -> Result<JsonObject<Vec<Vacation>>, Error> {
    println!("Messages::GetVacations");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let _ = check_token(&token, pool)?;
    vacations::table
        .load::<Vacation>(conn)
        .map(|res| JsonObject::new(res))
        .map_err(|err| Error::Dsl(err))
}

pub fn add_vacation(
    pool: web::Data<PgPool>,
    token: Token,
    new_vacation: NewVacation,
) -> Result<Vacation, Error> {
    println!("Messages::AddVacation");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let _ = check_token(&token, pool)?;
    diesel::insert_into(vacations::table)
        .values(new_vacation)
        .get_result(conn)
        .map_err(Error::Dsl)
}

pub fn update_vacation(
    pool: web::Data<PgPool>,
    token: Token,
    vacation: Vacation,
) -> Result<Vacation, Error> {
    println!("Messages::UpdateVacation");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let current_employee = check_token(&token, pool)?;
    match_ids(current_employee.id, vacation.employee_id)?;

    diesel::update(&vacation.clone())
        .set(vacation.clone())
        .get_result(conn)
        .map_err(Error::Dsl)
}

pub fn update_vacation_approval(
    pool: web::Data<PgPool>,
    token: Token,
    vacation: Vacation,
) -> Result<Vacation, Error> {
    println!("Messages::UpdateVacation");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let supervisor = check_token(&token, pool)?;
    match_ids(
        supervisor.id,
        vacation.supervisor_id.unwrap_or(-1),
    )?;

    diesel::update(&vacation.clone())
        .set(vacations::approved.eq(vacation.approved))
        .get_result(conn)
        .map_err(Error::Dsl)
}

pub fn remove_vacation(
    pool: web::Data<PgPool>,
    token: Token,
    vacation: Vacation,
) -> Result<(), Error> {
    println!("Messages::RemoveVacation");
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    let current_employee = check_token(&token, pool)?;
    match_ids(current_employee.id, vacation.employee_id)?;

    diesel::delete(&vacation)
        .execute(conn)
        .map(|_| ())
        .map_err(Error::Dsl)
}

fn employee_by_email(
    pool: web::Data<PgPool>,
    email: &str,
) -> Result<Employee, Error> {
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
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

pub fn check_token(
    token: &str,
    pool: web::Data<PgPool>,
) -> std::result::Result<Employee, Error> {
    let manager = pool.clone().get().unwrap();
    let conn = manager.deref();
    match sessions::table
        .filter(sessions::token.eq(token))
        .first::<Session>(conn)
    {
        Ok(session) => {
            let now = Utc::now();
            let expires_at = session.expiration;
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
