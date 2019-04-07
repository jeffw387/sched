use crate::schema::employees;
use diesel::prelude::*;
use serde::{
    Deserialize,
    Serialize,
};

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
    Debug, Clone, Identifiable, Serialize, Deserialize,
)]
pub struct Employee {
    pub id: i32,
    pub name: Name,
    pub phone_number: Option<String>,
}

#[derive(Clone, Debug, Insertable, Deserialize)]
#[table_name = "employees"]
pub struct NewEmployee {
    #[diesel(embed)]
    name: Name,
    phone_number: Option<String>,
}

impl NewEmployee {
    pub fn new(
        name: Name,
        phone_number: Option<String>,
    ) -> NewEmployee {
        NewEmployee { name, phone_number }
    }
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
