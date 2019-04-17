use super::employee::Employee;
use super::schema::shifts;
use diesel::sql_types::Text;
use std::str::FromStr;
use strum_macros::{
    Display,
    EnumString,
};

use serde::{
    Deserialize,
    Serialize,
};

#[derive(
    Clone,
    Copy,
    Debug,
    AsExpression,
    FromSqlRow,
    EnumString,
    Display,
    Deserialize,
    Serialize,
)]
#[sql_type = "Text"]
pub enum ShiftRepeat {
    NeverRepeat,
    EveryWeek,
    EveryDay,
}

enum_to_sql!(ShiftRepeat);
enum_from_sql!(ShiftRepeat);

#[derive(
    Clone,
    Debug,
    Identifiable,
    Associations,
    Serialize,
    Deserialize,
    Queryable,
)]
#[table_name = "shifts"]
#[belongs_to(Employee)]
pub struct Shift {
    pub id: i32,
    pub user_id: i32,
    pub employee_id: i32,
    pub year: i32,
    pub month: i32,
    pub day: i32,
    pub hour: i32,
    pub minute: i32,
    pub hours: i32,
    pub minutes: i32,
    pub shift_repeat: ShiftRepeat,
    pub every_x: i32,
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
    pub shift_repeat: ShiftRepeat,
    pub every_x: i32,
}

impl NewShift {
    pub fn new(
        user_id: i32,
        employee_id: i32,
        year: i32,
        month: i32,
        day: i32,
        hour: i32,
        minute: i32,
        hours: i32,
        minutes: i32,
        shift_repeat: ShiftRepeat,
        every_x: i32,
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
            shift_repeat,
            every_x,
        }
    }
}
