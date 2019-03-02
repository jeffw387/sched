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
impl Debug for DuplicateExists {
    fn fmt(&self, f: &mut Formatter) -> Result<(), Error> {
        write!(f, "An employee with that name already exists")
    }
}

pub struct UnknownError;
impl Debug for UnknownError {
    fn fmt(&self, f: &mut Formatter) -> Result<(), Error> {
        write!(f, "An unknown error occurred while adding an employee")
    }
}

pub struct NotFound;
impl Debug for NotFound {
    fn fmt(&self, f: &mut Formatter) -> Result<(), Error> {
        write!(f, "An employee with that name is not found")
    }
}

#[derive(Debug)]
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
) -> EmployeeResult {
    use schema::employees::dsl::*;
    let employee_result = get_employee(
        conn,
        new_employee.first,
        new_employee.last,
    );
    match employee_result {
        Err(EmployeeError::NotFound) => (),
        _ => return employee_result,
    }

    diesel::insert_into(employees::table())
        .values(&new_employee)
        .get_result(conn)
        .or(Err(EmployeeError::UnknownError))
}

pub fn get_employee(
    conn: &PgConnection,
    first_name: &str,
    last_name: &str,
) -> EmployeeResult {
    use schema::employees::dsl::*;
    match employees
        .filter(first.eq(first_name))
        .filter(last.eq(last_name))
        .load::<Employee>(conn)
    {
        Ok(existing) => {
            match existing.len().cmp(&1) {
                std::cmp::Ordering::Equal => {
                    Ok(existing[0].clone())
                }
                std::cmp::Ordering::Greater => {
                    Err(EmployeeError::DuplicateExists)
                }
                std::cmp::Ordering::Less => {
                    Err(EmployeeError::NotFound)
                }
            }
        }
        _ => Err(EmployeeError::UnknownError),
    }
}

pub fn get_employees(
    conn: &PgConnection,
) -> QueryResult<Vec<Employee>> {
    use schema::employees::dsl::*;
    employees.load::<Employee>(conn)
}


#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn add_get_remove() {
        let conn = establish_connection();
        let name = models::Name {
            first: "Frank".to_string(), 
            last: "Wright".to_string()
        };
        let new_employee =
            NewEmployee::new(name, None);
        let added_employee =
            add_employee(&conn, new_employee.clone())
                .unwrap();
        assert_eq!(
            added_employee.name,
            new_employee.name
        );
        let found_employee = get_employee(
            &conn,
            new_employee.name.clone(),
        )
        .unwrap();
        assert_eq!(
            found_employee.name,
            new_employee.name
        );
        assert_eq!(
            remove_employee(
                &conn,
                new_employee.name,
            )
            .unwrap(),
            1
        );
    }
}
