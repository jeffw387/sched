
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

/// Either a shift or an error
pub type Result = result::Result<Shift, Error>;

impl Employee {
    /// Add a shift to the given employee.
    /// Returns an error if a shift already starts
    /// at the given time.
    pub fn add_shift(
        &self,
        conn: &PgConnection,
        start: NaiveDateTime,
        duration_hours: f32,
    ) -> Result {
        let new_shift =
            NewShift::new(self.id, start, duration_hours);
        match self.get_shift(conn, start) {
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
        start_find: NaiveDateTime,
    ) -> Result {
        use crate::schema::shifts::dsl::*;
        match Shift::belonging_to(self)
            .filter(start.eq(start_find))
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
        start_find: NaiveDateTime,
    ) {
        match self.get_shift(conn, start_find) {
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

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn add_new_shift() {
        let conn = crate::establish_connection();
        use crate::employee::{
            self,
            Name,
        };
        let test_employee = employee::add_employee(
            &conn,
            Name {
                first: "Frank".to_string(),
                last: "Wright".to_string(),
            },
            None,
        )
        .expect(
            "Unable to add test employee Frank Wright!",
        );
        let start =
            chrono::NaiveDate::from_ymd(2000, 1, 31)
                .and_hms(10, 30, 0);
        let duration_hours = 10f32;
        let added_shift = test_employee
            .add_shift(&conn, start, duration_hours)
            .expect("Error adding test shift!");

        assert_eq!(start, added_shift.start);
        assert_eq!(
            duration_hours,
            added_shift.duration_hours
        );
        let modified_shift =
            Shift { duration_hours: 8f32, ..added_shift };
        let updated_shift = modified_shift
            .update(&conn)
            .expect("Unable to update shift!");

        assert_eq!(start, updated_shift.start);
        assert_eq!(8f32, updated_shift.duration_hours);

        test_employee.remove_shift(&conn, start);

        employee::remove_employee(
            &conn,
            test_employee.name,
        );
    }
}