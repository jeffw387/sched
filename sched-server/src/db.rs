use super::user as dbuser;
use actix::prelude::*;
use sched::message::LoginInfo;
use sched::user::{
    self,
    User,
};

use diesel::prelude::*;
use diesel::r2d2::{
    ConnectionManager,
    Pool,
};
use diesel::result::ConnectionError;
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
        let conn: &PgConnection = &self.0.get().expect(
            "Error: database connection not found!",
        );
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

pub enum Error {
    Dsl(ConnectionError),
    Usr(dbuser::Error),
    InvalidPassword,
}

impl Debug for Error {
    fn fmt(&self, f: &mut Formatter) -> std::fmt::Result {
        match self {
            Error::Dsl(d) => d.fmt(f),
            Error::InvalidPassword => {
                write!(f, "Incorrect password was entered!")
            }
            Error::Usr(u) => u.fmt(f),
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
