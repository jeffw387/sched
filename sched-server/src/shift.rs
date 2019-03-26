use super::employee::Employee;
use super::schema::shifts;

use diesel::prelude::*;
use serde::{
    Deserialize,
    Serialize,
};
use std::fmt::{
    Debug,
    Formatter,
};

#[derive(
    Clone,
    Debug,
    Identifiable,
    AsChangeset,
    Associations,
    Serialize,
    Deserialize,
    Queryable,
)]
#[table_name = "shifts"]
#[belongs_to(Employee)]
pub struct Shift {
    pub id: i32,
    pub employee_id: i32,
    pub year: i32,
    pub month: i32,
    pub day: i32,
    pub hour: i32,
    pub minute: i32,
    pub hours: i32,
    pub minutes: i32,
}

#[derive(Debug, Insertable)]
#[table_name = "shifts"]
pub struct NewShift {
    employee_id: i32,
    pub year: i32,
    pub month: i32,
    pub day: i32,
    pub hour: i32,
    pub minute: i32,
    pub hours: i32,
    pub minutes: i32,
}

impl NewShift {
    pub fn new(
        employee_id: i32,
        year: i32,
        month: i32,
        day: i32,
        hour: i32,
        minute: i32,
        hours: i32,
        minutes: i32,
    ) -> NewShift {
        NewShift {
            employee_id,
            year,
            month,
            day,
            hour,
            minute,
            hours,
            minutes,
        }
    }
}

/// Error codes related to shifts
pub enum Error {
    Unknown,
    ShiftExists,
    ShiftNotFound,
    Fmt(std::fmt::Error),
    Dsl(diesel::result::Error),
}
impl Debug for Error {
    fn fmt(&self, f: &mut Formatter) -> std::fmt::Result {
        match self {
            Error::Unknown => write!(f, "Unknown error!"),
            Error::ShiftExists => {
                write!(
                    f,
                    "The shift being added already exists"
                )
            }
            Error::ShiftNotFound => {
                write!(f, "Shift not found at that time")
            }
            Error::Fmt(fmt_error) => fmt_error.fmt(f),
            Error::Dsl(dsl_error) => dsl_error.fmt(f),
        }
    }
}

impl From<Error> for actix_web::Error {
    fn from(err: Error) -> Self {
        actix_web::error::ErrorBadRequest(format!(
            "{:?}",
            err
        ))
    }
}

/// Either a shift or an error
pub type Result = std::result::Result<Shift, Error>;

impl Employee {
    /// Add a shift to the given employee.
    /// Returns an error if a shift already starts
    /// at the given time.
    pub fn add_shift(
        &self,
        conn: &PgConnection,
        year: i32,
        month: i32,
        day: i32,
        hour: i32,
        minute: i32,
        hours: i32,
        minutes: i32,
    ) -> Result {
        let new_shift = NewShift::new(
            self.id, year, month, day, hour, minute, hours,
            minutes,
        );
        match self
            .get_shift(conn, year, month, day, hour, minute)
        {
            Ok(_) => return Err(Error::ShiftExists),
            _ => (),
        };

        diesel::insert_into(shifts::table)
            .values(new_shift)
            .get_result(conn)
            .map_err(|e| Error::Dsl(e))
    }

    /// Get the shift starting at the given time,
    /// or an error if one isn't found
    pub fn get_shift(
        &self,
        conn: &PgConnection,
        year: i32,
        month: i32,
        day: i32,
        hour: i32,
        minute: i32,
    ) -> Result {
        match Shift::belonging_to(self)
            .filter(shifts::year.eq(year))
            .filter(shifts::month.eq(month))
            .filter(shifts::day.eq(day))
            .filter(shifts::hour.eq(hour))
            .filter(shifts::minute.eq(minute))
            .first::<Shift>(conn)
        {
            Ok(found) => Ok(found),
            Err(err) => Err(Error::Dsl(err)),
        }
    }

    /// Get all shifts for the given employee, or return
    /// an error on failure
    pub fn get_shifts(
        &self,
        conn: &PgConnection,
    ) -> std::result::Result<Vec<Shift>, Error> {
        match Shift::belonging_to(self).load::<Shift>(conn)
        {
            Ok(shifts) => return Ok(shifts),
            Err(err) => return Err(Error::Dsl(err)),
        }
    }

    /// Remove the shift starting at the given time
    /// if it exists
    pub fn remove_shift(
        &self,
        conn: &PgConnection,
        year: i32,
        month: i32,
        day: i32,
        hour: i32,
        minute: i32,
    ) {
        match self
            .get_shift(conn, year, month, day, hour, minute)
        {
            Ok(shift_to_delete) => {
                let _ = diesel::delete(&shift_to_delete)
                    .execute(conn);
            }
            _ => return (),
        };
    }
}

impl Shift {
    /// Uses the shift structure given to update itself in
    /// the database
    pub fn update(&self, conn: &PgConnection) -> Result {
        diesel::update(self)
            .set(self)
            .get_result(conn)
            .map_err(|e| Error::Dsl(e))
    }
}
