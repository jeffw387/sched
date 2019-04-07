use super::employee::Employee;
use super::schema::shifts;

use serde::{
    Deserialize,
    Serialize,
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
    pub user_id: i32,
}

#[derive(Debug, Insertable, Deserialize)]
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
    pub user_id: i32,
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
        user_id: i32,
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
            user_id,
        }
    }
}
