use chrono::{
    self,
    Duration,
    NaiveDateTime,
};

pub struct Shift {
    pub start: NaiveDateTime,
    pub duration: Duration,
}

impl Shift {
    pub fn new(
        start: NaiveDateTime,
        duration: Duration,
    ) -> Shift {
        Shift { start, duration }
    }
}

#[derive(Insertable, Clone, Debug, PartialEq)]
#[table_name = "employees"]
pub struct Name {
    pub first: String,
    pub last: String
}

pub struct Employee {
    pub id: i32,
    pub name: Name,
    pub phone_number: Option<String>,
}

use super::schema::employees;

#[derive(Insertable)]
#[table_name = "employees"]
pub struct NewEmployee<'a> {
    pub first: &'a str,
    pub last: &'a str,
    pub phone_number: Option<&'a str>,
}

impl<'a> NewEmployee<'a> {
    pub fn new(
        first: &'a str,
        last: &'a str,
        phone_number: Option<&'a str>,
    ) -> NewEmployee<'a> {
        NewEmployee { first, last, phone_number }
    }
}
