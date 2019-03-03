use crate::schema::shifts;
use chrono::{
    self,
    NaiveDate,
    NaiveTime,
};
use crate::employee::Employee;

#[derive(Clone, Debug, Insertable)]
#[table_name = "shifts"]
pub struct NewShift {
    pub employee_id: i32,
    pub start_date: NaiveDate,
    pub start_time: NaiveTime,
    pub duration_hours: f32,
}

impl NewShift {
    pub fn new(
        employee: &Employee,
        start_date: NaiveDate,
        start_time: NaiveTime,
        duration_hours: f32,
    ) -> NewShift {
        NewShift {
            employee_id: employee.id,
            start_date,
            start_time,
            duration_hours,
        }
    }
}

#[derive(Clone, Debug, Identifiable)]
#[table_name = "shifts"]
pub struct Shift {
    pub id: i32,
    pub employee_id: i32,
    pub start_date: NaiveDate,
    pub start_time: NaiveTime,
    pub duration_hours: f32,
}