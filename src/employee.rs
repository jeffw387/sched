use crate::schema::*;
use diesel::pg::PgConnection;
use diesel::prelude::*;
use std::{
    fmt::{
        Debug,
        Formatter,
    },
    result,
};

/// Employee's first and last names as Strings
#[derive(Insertable, Clone, Debug, PartialEq)]
#[table_name = "employees"]
pub struct Name {
    pub first: String,
    pub last: String,
}

/// A structure mapping to an employee in the database
#[derive(Identifiable, Debug, Clone)]
pub struct Employee {
    pub id: i32,
    pub name: Name,
    pub phone_number: Option<String>,
}

/// Implements queryable manually to translate
/// name into two strings in the database
impl Queryable<employees::SqlType, diesel::pg::Pg>
    for Employee
{
    type Row = (i32, String, String, Option<String>);

    fn build(row: Self::Row) -> Self {
        Employee {
            id: row.0,
            name: Name { first: row.1, last: row.2 },
            phone_number: row.3,
        }
    }
}

#[derive(Insertable, Clone, Debug)]
#[table_name = "employees"]
struct NewEmployee {
    #[diesel(embed)]
    name: Name,
    phone_number: Option<String>,
}

impl NewEmployee {
    fn new(
        name: Name,
        phone_number: Option<String>,
    ) -> NewEmployee {
        NewEmployee { name, phone_number }
    }
}

/// Employee error codes
pub enum Error {
    DuplicateExists,
    NotFound,
    UnknownError,
}

impl Debug for Error {
    fn fmt(&self, f: &mut Formatter) -> std::fmt::Result {
        match self {
            Error::DuplicateExists => {
                write!(
                    f,
                    "An employee with that name already exists"
                )
            }
            Error::NotFound => {
                write!(
                    f,
                    "An employee with that name is not found"
                )
            }
            Error::UnknownError => {
                write!(
                    f,
                    "An unknown error occurred while adding an employee"
                )
            }
        }
    }
}

/// Either an employee or an error code
pub type Result = result::Result<Employee, Error>;

/// Add a new employee to the database.
/// If an employee already exists with that name, return it.
pub fn add_employee(
    conn: &PgConnection,
    name: Name,
    phone_number: Option<String>,
) -> Result {
    let employee_result = get_employee(conn, name.clone());
    match employee_result {
        Err(Error::NotFound) => (),
        _ => return employee_result,
    }

    let new_employee = NewEmployee::new(name, phone_number);
    diesel::insert_into(employees::table)
        .values(&new_employee)
        .get_result(conn)
        .or(Err(Error::UnknownError))
}
use diesel::dsl::{
    And,
    Eq,
    Filter,
};

fn filter_by_name(
    name: Name,
) -> Filter<
    crate::schema::employees::table,
    And<
        Eq<employees::first, String>,
        Eq<employees::last, String>,
    >,
> {
    use self::employees::dsl::*;
    employees
        .filter(first.eq(name.first))
        .filter(last.eq(name.last))
}

/// Look up an employee by name. Returns errors for not found
/// or if duplicates exist in the database.
pub fn get_employee(
    conn: &PgConnection,
    name: Name,
) -> Result {
    match filter_by_name(name).load::<Employee>(conn) {
        Ok(existing) => {
            match existing.len().cmp(&1) {
                std::cmp::Ordering::Equal => {
                    Ok(existing[0].clone())
                }
                std::cmp::Ordering::Greater => {
                    Err(Error::DuplicateExists)
                }
                std::cmp::Ordering::Less => {
                    Err(Error::NotFound)
                }
            }
        }
        _ => Err(Error::UnknownError),
    }
}

/// Get all the employees in the database as a vector
pub fn get_employees(
    conn: &PgConnection,
) -> QueryResult<Vec<Employee>> {
    use self::employees::dsl::*;
    employees.load::<Employee>(conn)
}

/// Remove an employee with the given name, if they exist
pub fn remove_employee(conn: &PgConnection, name: Name) {
    let _ =
        diesel::delete(filter_by_name(name)).execute(conn);
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn add_get_remove() {
        let conn = crate::establish_connection();
        let name = Name {
            first: "Frank".to_string(),
            last: "Wrong".to_string(),
        };
        let added_employee =
            add_employee(&conn, name.clone(), None)
                .unwrap();
        assert_eq!(added_employee.name, name);
        let found_employee =
            get_employee(&conn, name.clone()).unwrap();
        assert_eq!(found_employee.name, name);
        remove_employee(&conn, name);
    }
}
