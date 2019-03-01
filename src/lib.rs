pub mod models;
pub mod schema;

#[macro_use]
extern crate diesel;

use self::models::{
    Employee,
    NewEmployee,
};
use diesel::associations::*;
use diesel::pg::PgConnection;
use diesel::prelude::*;
use dotenv::dotenv;
use std::{
    env,
    result,
    fmt::{Display, Formatter, Error}
};

pub fn establish_connection() -> PgConnection {
    dotenv().ok();

    let db_url = env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set");
    PgConnection::establish(&db_url)
        .expect(&format!("Error connecting to {}", db_url))
}

pub struct DuplicateExists;
impl Display for DuplicateExists {
    fn fmt(&self, f: &mut Formatter) -> Result<(), Error> {
        write!(f, "An employee with that name already exists")
    }
}

pub struct UnknownError;
impl Display for UnknownError {
    fn fmt(&self, f: &mut Formatter) -> Result<(), Error> {
        write!(f, "An unknown error occurred while adding an employee")
    }
}

pub struct NotFound;
impl Display for NotFound {
    fn fmt(&self, f: &mut Formatter) -> Result<(), Error> {
        write!(f, "An employee with that name is not found")
    }
}

pub enum EmployeeError {
    DuplicateExists,
    NotFound,
    UnknownError,
}

pub type EmployeeResult =
    result::Result<Employee, EmployeeError>;

pub fn add_employee<'a>(
    conn: &PgConnection,
    new_employee: NewEmployee<'a>,
) -> Employee {
    use schema::employees::dsl::*;

    diesel::insert_into(employees::table())
        .values(&new_employee)
        .get_result(conn)
        .expect("Error adding employee!")
}
