use crate::schema::employees;
use diesel::prelude::*;
use serde::{
    Deserialize,
    Serialize,
};
use super::message::LoginInfo;
use diesel::sql_types::Text;
use std::str::FromStr;
use strum_macros::{
    Display,
    EnumString,
};
use crypto::pbkdf2 as crypt;
use super::datetime::{
    self,
    DateTime,
};
use super::schema::sessions;

#[derive(
    Clone,
    Debug,
    Insertable,
    Serialize,
    Deserialize,
    AsChangeset,
    Queryable,
)]
#[table_name = "employees"]
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
    pub year: i32,
    pub month: i32,
    pub day: i32,
    pub hour: i32,
    pub minute: i32,
    pub token: String,
}

#[derive(Serialize, Deserialize)]
struct TokenData {
    employee_id: i32,
    expires: DateTime,
}

impl NewSession {
    pub fn new(
        employee_id: i32,
        expires: DateTime,
    ) -> NewSession {
        let token_data = TokenData { employee_id, expires };
        let token = crypt::pbkdf2_simple(
            &serde_json::to_string(&token_data)
                .expect("Error serializing token data!"),
            1,
        )
        .expect("Error hashing token data!");
        NewSession {
            employee_id,
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
    pub employee_id: i32,
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

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ClientSideEmployee {
    pub id: i32,
    pub email: String,
    pub startup_settings: Option<i32>,
    pub level: EmployeeLevel,
    pub name: Name,
    pub phone_number: Option<String>,
}

impl From<Employee> for ClientSideEmployee {
    fn from(employee: Employee) -> Self {
        ClientSideEmployee { 
            id: employee.id, 
            email: employee.email,
            startup_settings: employee.startup_settings,
            level: employee.level,
            name: employee.name,
            phone_number: employee.phone_number
        }
    }
}

#[derive(
    Debug, Clone, Identifiable, Serialize, Deserialize,
)]
pub struct Employee {
    pub id: i32,
    pub email: String,
    pub password_hash: String,
    pub startup_settings: Option<i32>,
    pub level: EmployeeLevel,
    pub name: Name,
    pub phone_number: Option<String>,
}

#[derive(Clone, Debug, Insertable, Deserialize)]
#[table_name = "employees"]
pub struct NewEmployee {
    pub email: String,
    pub password_hash: String,
    pub startup_settings: Option<i32>,
    pub level: EmployeeLevel,
    #[diesel(embed)]
    pub name: Name,
    pub phone_number: Option<String>,
}

impl NewEmployee {
    pub fn new(
        login_info: LoginInfo,
        startup_settings: Option<i32>,
        level: EmployeeLevel,
        name: Name,
        phone_number: Option<String>,
    ) -> NewEmployee {
        let password_hash = crypt::pbkdf2_simple(
                &login_info.password,
                1,
            )
            .expect("Failed to hash password!");
        NewEmployee { 
            email: login_info.email,
            password_hash,
            startup_settings,
            level,
            name, 
            phone_number
        }
    }
}

/// Implements queryable manually to translate
/// name into two strings in the database
impl Queryable<employees::SqlType, diesel::pg::Pg>
    for Employee
{
    type Row = (i32, String, String, Option<i32>, EmployeeLevel, String, String, Option<String>);

    fn build(row: Self::Row) -> Self {
        Employee {
            id: row.0,
            email: row.1,
            password_hash: row.2,
            startup_settings: row.3,
            level: row.4,
            name: Name { first: row.5, last: row.6 },
            phone_number: row.7,
        }
    }
}
