use super::user as dbuser;
use crate::employee::{
    self,
    Employee,
};
use crate::shift::{
    self,
    Shift,
};
use actix::prelude::*;
use diesel::prelude::*;
use diesel::r2d2::{
    ConnectionManager,
    Pool,
};
use sched::message::LoginInfo;
use std::fmt::{
    Debug,
    Formatter,
};
use serde::{Serialize};

pub struct LoginRequest(pub LoginInfo);

pub type LoginResult = std::result::Result<String, Error>;
impl Message for LoginRequest {
    type Result = LoginResult;
}

impl Handler<LoginRequest> for DbExecutor {
    type Result = LoginResult;

    fn handle(
        &mut self,
        req: LoginRequest,
        _: &mut Self::Context,
    ) -> LoginResult {
        let conn =
            &self.0.get().map_err(|e| Error::R2(e))?;
        let username = req.0.email;
        let password = req.0.password;
        println!("Trying login with {} and {}", username, password);
        let usr = super::user::get_user(conn, &username)
            .map_err(|err| Error::Usr(err))?;
        match usr.check_password(&password).map_err(|e| {
            println!(
                "Error while checking password: {}",
                e
            );
        }) {
            Ok(true) => {
                println!("Password matches.");
                Ok("test token".to_owned())}
            Ok(false) => {
                println!(
                    "Error during login: invalid password"
                );
                Err(Error::InvalidPassword)
            }
            Err(e) => {
                println!(
                    "Login request: unknown error {:?}",
                    e
                );
                Err(Error::Misc("unknown error"))
            }
        }
    }
}

pub struct CreateUser(pub LoginInfo);
pub type CreateUserResult = std::result::Result<(), Error>;
impl Message for CreateUser {
    type Result = CreateUserResult;
}

impl Handler<CreateUser> for DbExecutor {
    type Result = CreateUserResult;

    fn handle(
        &mut self,
        req: CreateUser,
        _: &mut Self::Context,
    ) -> Self::Result {
        let conn =
            &self.0.get().map_err(|e| Error::R2(e))?;
        let username = req.0.email;
        let password = req.0.password;
        println!(
            "Creating user {} with password {}",
            username, password
        );
        match super::user::get_user(conn, &username) {
            Ok(_) => {
                println!(
                    "Create user: a user with that email already exists."
                );
                Err(Error::UserExists)
            }
            Err(e) => {
                println!("get_user failed: {:?}", e);
                dbg!(&e);
                match e {
                    // If user is not found, 
                    // try to add the user
                    super::user::Error::NotFound => {
                        match super::user::add_user(
                            conn, username, password,
                        ) {
                            Ok(_) => Ok(()),
                            Err(create_err) => {
                                println!(
                                    "Create user error: {:?}",
                                    create_err
                                );
                                Err(Error::Usr(create_err))
                            }
                        }
                    }
                    e => {
                        println!(
                            "Create user error: {:?}",
                            e
                        );
                        Err(Error::Usr(e))
                    }
                }
            }
        }
    }
}

pub struct GetEmployees {}

#[derive(Serialize, Debug)]
pub struct EmployeesQuery {
    pub employees: Vec<Employee>
}

type GetEmployeesResult =
    std::result::Result<EmployeesQuery, Error>;
impl Message for GetEmployees {
    type Result = GetEmployeesResult;
}

impl Handler<GetEmployees> for DbExecutor {
    type Result = GetEmployeesResult;

    fn handle(
        &mut self,
        _: GetEmployees,
        _: &mut Self::Context,
    ) -> GetEmployeesResult {
        let conn = &self.0.get().unwrap();
        employee::get_employees(conn)
            .map_err(|e| Error::Dsl(e.into()))
            .map(|emps| EmployeesQuery{employees: emps})
    }
}

pub struct GetShifts(pub Employee);

#[derive(Serialize, Debug)]
pub struct ShiftsQuery {
    pub shifts: Vec<Shift>
}

pub type GetShiftsResult =
    std::result::Result<ShiftsQuery, Error>;
impl Message for GetShifts {
    type Result = GetShiftsResult;
}

impl Handler<GetShifts> for DbExecutor {
    type Result = GetShiftsResult;

    fn handle(
        &mut self,
        msg: GetShifts,
        _: &mut Self::Context,
    ) -> GetShiftsResult {
        let conn = &self.0.get().unwrap();
        msg.0.get_shifts(conn).map_err(|e| Error::Shft(e))
            .map(|shifts| ShiftsQuery{shifts: shifts})
    }
}

pub enum Error {
    Dsl(diesel::result::Error),
    R2(r2d2::Error),
    Usr(dbuser::Error),
    Emp(employee::Error),
    Shft(shift::Error),
    InvalidPassword,
    UserExists,
    Misc(&'static str),
}

impl Debug for Error {
    fn fmt(&self, f: &mut Formatter) -> std::fmt::Result {
        match self {
            Error::Dsl(d) => d.fmt(f),
            Error::R2(r) => r.fmt(f),
            Error::Usr(u) => u.fmt(f),
            Error::Emp(e) => e.fmt(f),
            Error::Shft(s) => s.fmt(f),
            Error::InvalidPassword => {
                write!(f, "Incorrect password was entered!")
            }
            Error::UserExists => {
                write!(
                    f,
                    "A user with that email already exists!"
                )
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
