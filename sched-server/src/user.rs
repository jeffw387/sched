use super::datetime::{
    self,
    DateTime,
};
use super::message::LoginInfo;
use super::schema::sessions;
use super::schema::users;
use crypto::pbkdf2 as crypt;
use diesel::sql_types::Text;
use serde::{
    Deserialize,
    Serialize,
};
use std::str::FromStr;
use strum_macros::{
    AsRefStr,
    Display,
    EnumString,
};

#[derive(Clone, Debug, Insertable)]
#[table_name = "users"]
pub struct NewUser {
    email: String,
    password_hash: String,
    level: UserLevel,
}

impl NewUser {
    pub fn new(
        login_info: LoginInfo,
        level: UserLevel,
    ) -> NewUser {
        let new_user = NewUser {
            email: login_info.email,
            password_hash: crypt::pbkdf2_simple(
                &login_info.password,
                1,
            )
            .expect("Failed to hash password!"),
            level,
        };
        println!("NewUser created: {:#?}", new_user);
        new_user
    }
}

#[derive(
    Clone,
    Copy,
    Debug,
    AsExpression,
    FromSqlRow,
    EnumString,
    Display,
    Deserialize,
    Serialize,
)]
#[sql_type = "Text"]
pub enum UserLevel {
    Read,
    Supervisor,
    Admin,
}

enum_from_sql!(UserLevel);
enum_to_sql!(UserLevel);

#[derive(
    Identifiable,
    Queryable,
    AsChangeset,
    Debug,
)]
pub struct User {
    pub id: i32,
    pub email: String,
    pub password_hash: String,
    pub startup_settings: Option<i32>,
    pub level: UserLevel,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ClientSideUser {
    pub id: i32,
    pub level: UserLevel
}

impl ClientSideUser {
    pub fn from(user: User) -> Self {
        ClientSideUser {
            id: user.id,
            level: user.level
        }
    }
}

#[derive(Insertable, Debug)]
#[table_name = "sessions"]
pub struct NewSession {
    pub user_id: i32,
    pub year: i32,
    pub month: i32,
    pub day: i32,
    pub hour: i32,
    pub minute: i32,
    pub token: String,
}

#[derive(Serialize, Deserialize)]
struct TokenData {
    user_id: i32,
    expires: DateTime,
}

impl NewSession {
    pub fn new(
        user_id: i32,
        expires: DateTime,
    ) -> NewSession {
        let token_data = TokenData { user_id, expires };
        let token = crypt::pbkdf2_simple(
            &serde_json::to_string(&token_data)
                .expect("Error serializing token data!"),
            1,
        )
        .expect("Error hashing token data!");
        NewSession {
            user_id,
            year: expires.0,
            month: expires.1,
            day: expires.2,
            hour: expires.3,
            minute: expires.4,
            token,
        }
    }
}

#[derive(
    Debug,
    Serialize,
    Deserialize,
    Queryable,
    Identifiable,
    AsChangeset,
)]
pub struct Session {
    pub id: i32,
    pub user_id: i32,
    pub year: i32,
    pub month: i32,
    pub day: i32,
    pub hour: i32,
    pub minute: i32,
    pub token: String,
}

impl Session {
    pub fn expires(&self) -> datetime::DateTime {
        (
            self.year,
            self.month,
            self.day,
            self.hour,
            self.minute,
        )
    }
}
