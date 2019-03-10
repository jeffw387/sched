use super::user::{
    self,
    User,
};
use actix::prelude::*;

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

pub struct DbExecutor(
    pub Pool<ConnectionManager<PgConnection>>,
);

impl Actor for DbExecutor {
    type Context = SyncContext<Self>;
}

pub struct LoginInfo {
    pub username: String,
    pub password: String,
}

pub struct Settings {}

pub enum Error {
    Dsl(ConnectionError),
    Usr(user::Error),
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

type UserVecResult = std::result::Result<Vec<User>, Error>;

pub struct GetUsers;
impl Message for GetUsers {
    type Result = UserVecResult;
}

impl Handler<GetUsers> for DbExecutor {
    type Result = UserVecResult;

    fn handle(
        &mut self,
        _: GetUsers,
        _: &mut Self::Context,
    ) -> UserVecResult {
        let conn: &PgConnection = &self.0.get().expect(
            "Error: database connection not found!",
        );

        match user::get_users(conn) {
            Ok(user_vec) => Ok(user_vec),
            Err(user_err) => Err(Error::Usr(user_err)),
        }
    }
}

pub struct LoginRequest(LoginInfo);
type LoginResult = std::result::Result<String, Error>;
impl Message for LoginRequest {
    type Result = LoginResult;
}

// impl Handler<LoginRequest> for DbExecutor {
//     type Result = LoginResult;

//     fn handle(&mut self, req: LoginRequest, _: &mut Self::Context) -> LoginResult {
//         futures::
//     }
// }

// impl Handler<LoginRequest> for DbConnection {
//     type Result = std::result::Result<Session, Error>;

//     fn handle(&mut self, msg: LoginRequest, _: &mut Self::Context) -> Self::Result {
//         let LoginInfo{username, password} = msg.info;
//         let connection = match &self.connection {
//             Some(conn) => conn,
//             None => return Err(Error::Dsl(ConnectionError::BadConnection("Connection not valid!".to_owned())))
//         };
//         use super::token::Token;
//         let user = super::user::get_user(&connection, &username)
//             .map_err(|_| super::user::add_user(&connection, username.clone(), password))
//             .map_err(|e| {panic!("Error adding user: {:?}", e.err().unwrap()); });
//         let mut new_token = Token::create(&username);
//         Ok(Session{token: "test".to_string()})
//     }
// }
