use super::config::EmployeeColor;
use super::message::LoginInfo;
use super::schema::sessions;
use crate::schema::employees;
use chrono::{
    DateTime,
    Utc,
};
use crypto::pbkdf2 as crypt;
use diesel::prelude::*;
use diesel::sql_types::Text;
use serde::{
    Deserialize,
    Serialize,
};
use std::str::FromStr;
use strum_macros::{
    Display,
    EnumString,
};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Name {
    pub first: String,
    pub last: String,
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
pub enum EmployeeLevel {
    Read,
    Supervisor,
    Admin,
}

enum_from_sql!(EmployeeLevel);
enum_to_sql!(EmployeeLevel);

#[derive(Insertable, Debug)]
#[table_name = "sessions"]
pub struct NewSession {
    pub employee_id: i32,
    pub expiration: DateTime<Utc>,
    pub token: String,
}

#[derive(Serialize, Deserialize)]
struct TokenData {
    employee_id: i32,
    expiration: DateTime<Utc>,
}

impl NewSession {
    pub fn new(
        employee_id: i32,
        expiration: DateTime<Utc>,
    ) -> NewSession {
        let token_data =
            TokenData { employee_id, expiration };
        let token = crypt::pbkdf2_simple(
            &serde_json::to_string(&token_data)
                .expect("Error serializing token data!"),
            1,
        )
        .expect("Error hashing token data!");
        NewSession { employee_id, expiration, token }
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
    pub employee_id: i32,
    pub expiration: DateTime<Utc>,
    pub token: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ClientSideEmployee {
    pub id: i32,
    pub email: String,
    pub active_config: Option<i32>,
    pub level: EmployeeLevel,
    pub first: String,
    pub last: String,
    pub phone_number: Option<String>,
    pub default_color: EmployeeColor,
}

impl From<Employee> for ClientSideEmployee {
    fn from(employee: Employee) -> Self {
        ClientSideEmployee {
            id: employee.id,
            email: employee.email,
            active_config: employee.active_config,
            level: employee.level,
            first: employee.first,
            last: employee.last,
            phone_number: employee.phone_number,
            default_color: employee.default_color,
        }
    }
}

#[derive(
    Debug,
    Clone,
    Identifiable,
    Serialize,
    Deserialize,
    Queryable,
)]
pub struct Employee {
    pub id: i32,
    pub email: String,
    pub password_hash: String,
    pub active_config: Option<i32>,
    pub level: EmployeeLevel,
    pub first: String,
    pub last: String,
    pub phone_number: Option<String>,
    pub default_color: EmployeeColor,
}

#[derive(Clone, Debug, Insertable, Deserialize)]
#[table_name = "employees"]
pub struct NewEmployee {
    pub email: String,
    pub password_hash: String,
    pub active_config: Option<i32>,
    pub level: EmployeeLevel,
    pub first: String,
    pub last: String,
    pub phone_number: Option<String>,
    pub default_color: EmployeeColor,
}

impl NewEmployee {
    pub fn new(
        login_info: LoginInfo,
        active_config: Option<i32>,
        level: EmployeeLevel,
        first: String,
        last: String,
        phone_number: Option<String>,
        default_color: EmployeeColor,
    ) -> NewEmployee {
        let password_hash =
            crypt::pbkdf2_simple(&login_info.password, 1)
                .expect("Failed to hash password!");
        NewEmployee {
            email: login_info.email,
            password_hash,
            active_config,
            level,
            first,
            last,
            phone_number,
            default_color,
        }
    }
}
