use crate::employee::Employee;
use crate::schema::shifts;
use chrono::{
    self,
    NaiveDateTime,
};
use diesel::prelude::*;
use diesel::pg::PgConnection;
use std::fmt::{
    Debug,
    Formatter,
};
use std::result;

#[derive(Debug, Associations, Insertable)]
#[table_name = "shifts"]
#[belongs_to(Employee)]
pub struct NewShift {
    pub employee_id: i32,
    pub start: NaiveDateTime,
    pub duration_hours: f32,
}

impl NewShift {
    pub fn new(
        start: NaiveDateTime,
        duration_hours: f32,
    ) -> NewShift {
        NewShift {
            employee_id: 0,
            start,
            duration_hours,
        }
    }
}

#[derive(Clone, Debug, Identifiable, Queryable, Associations)]
#[table_name = "shifts"]
#[belongs_to(Employee)]
pub struct Shift {
    pub id: i32,
    pub employee_id: i32,
    pub start: NaiveDateTime,
    pub duration_hours: f32,
}

pub enum Error {
    Unknown,
    Fmt(std::fmt::Error),
    Dsl(diesel::result::Error)
}
impl Debug for Error {
    fn fmt(&self, f: &mut Formatter) -> std::fmt::Result {
        match self {
            Error::Unknown => write!(f, "Unknown error!"),
            Error::Fmt(fmt_error) => fmt_error.fmt(f),
            Error::Dsl(dsl_error) => dsl_error.fmt(f)
        }
    }
}

type Result = result::Result<Shift, Error>;

impl Employee {
    pub fn add_shift(
        &self,
        conn: &PgConnection,
        employee: &Employee,
        shift: &mut NewShift,
    ) -> Result {
        use crate::schema::shifts::dsl::*;
        shift.employee_id = employee.id;
        let shift = shift as &NewShift;
        diesel::insert_into(shifts)
            .values(shift)
            .get_result(&conn)
            .map_err(|e| Error::Dsl(e))
    }

    pub fn get_shift(&self, conn: &PgConnection, start_find: NaiveDateTime) -> Result {
        use crate::schema::shifts::dsl::*;
        Ok(Shift::belonging_to(self)
            .filter(start.eq(start_find))
            .load::<Shift>(&conn).unwrap()[0])
    }
}
