use std::{
    fmt::{
        Debug,
        Error,
        Formatter,
    },
    result,
};
use diesel::pg::PgConnection;
use diesel::prelude::*;
use crate::schema::*;

#[derive(Insertable, Clone, Debug, PartialEq)]
#[table_name = "employees"]
pub struct Name {
    pub first: String,
    pub last: String,
}

#[derive(Identifiable, Debug, Clone)]
pub struct Employee {
    pub id: i32,
    pub name: Name,
    pub phone_number: Option<String>,
}

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
pub struct NewEmployee {
    #[diesel(embed)]
    pub name: Name,
    pub phone_number: Option<String>,
}

impl NewEmployee {
    pub fn new(
        name: Name,
        phone_number: Option<String>,
    ) -> NewEmployee {
        NewEmployee { name, phone_number }
    }
}

pub struct DuplicateExists;
impl Debug for DuplicateExists {
    fn fmt(&self, f: &mut Formatter) -> Result<(), Error> {
        write!(
            f,
            "An employee with that name already exists"
        )
    }
}

pub struct UnknownError;
impl Debug for UnknownError {
    fn fmt(&self, f: &mut Formatter) -> Result<(), Error> {
        write!(
            f,
            "An unknown error occurred while adding an employee"
        )
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

pub fn add_employee(
    conn: &PgConnection,
    new_employee: NewEmployee,
) -> EmployeeResult {
    use crate::schema::employees::dsl::*;
    let employee_result =
        get_employee(conn, new_employee.name.clone());
    match employee_result {
        Err(EmployeeError::NotFound) => (),
        _ => return employee_result,
    }

    diesel::insert_into(employees)
        .values(&new_employee)
        .get_result(conn)
        .or(Err(EmployeeError::UnknownError))
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

pub fn get_employee(
    conn: &PgConnection,
    name: Name,
) -> EmployeeResult {
    match filter_by_name(name).load::<Employee>(conn) {
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
    use self::employees::dsl::*;
    employees.load::<Employee>(conn)
}

pub fn remove_employee(
    conn: &PgConnection,
    name: Name,
) -> QueryResult<usize> {
    diesel::delete(filter_by_name(name)).execute(conn)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn add_get_remove() {
        let conn = crate::establish_connection();
        let name = Name {
            first: "Frank".to_string(),
            last: "Wright".to_string(),
        };
        let new_employee = NewEmployee::new(name, None);
        let added_employee =
            add_employee(&conn, new_employee.clone())
                .unwrap();
        assert_eq!(added_employee.name, new_employee.name);
        let found_employee =
            get_employee(&conn, new_employee.name.clone())
                .unwrap();
        assert_eq!(found_employee.name, new_employee.name);
        assert_eq!(
            remove_employee(&conn, new_employee.name,)
                .unwrap(),
            1
        );
    }
}