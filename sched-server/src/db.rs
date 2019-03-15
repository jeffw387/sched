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
        let usr = super::user::get_user(conn, &username)
            .map_err(|err| Error::Usr(err))?;
        match usr
            .check_password(&password)
            .expect("Error while checking password!")
        {
            true => Ok("test token".to_owned()),
            false => Err(Error::InvalidPassword),
        }
    }
}

pub struct GetEmployees {}

type GetEmployeesResult =
    std::result::Result<Vec<Employee>, Error>;
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
    }
}

pub struct GetShifts(pub Employee);

pub type GetShiftsResult =
    std::result::Result<Vec<Shift>, Error>;
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
    }
}

pub enum Error {
    Dsl(diesel::result::Error),
    R2(r2d2::Error),
    Usr(dbuser::Error),
    Emp(employee::Error),
    Shft(shift::Error),
    InvalidPassword,
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
