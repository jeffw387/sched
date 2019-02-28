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

#[derive(Queryable)]
pub struct Employee {
    pub id: i32,
    pub first: String,
    pub last: String,
    pub phone_number: Option<String>,
}

use super::schema::employees;

#[derive(Insertable)]
#[table_name = "employees"]
pub struct NewEmployee<'a> {
    pub first: &'a str,
    pub last: &'a str,
    pub phone_number: &'a str,
}

impl<'a> NewEmployee<'a> {
    pub fn new(
        first: &'a str,
        last: &'a str,
        phone_number: &'a str,
    ) -> NewEmployee<'a> {
        NewEmployee { first, last, phone_number }
    }
}
