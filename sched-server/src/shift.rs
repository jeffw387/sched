use super::employee::Employee;
use super::schema::{
    shifts,
    vacations,
};
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
    AsChangeset,
)]
#[table_name = "shifts"]
#[belongs_to(Employee)]
pub struct Shift {
    pub id: i32,
    pub supervisor_id: i32,
    pub employee_id: Option<i32>,
    pub year: i32,
    pub month: i32,
    pub day: i32,
    pub hour: i32,
    pub minute: i32,
    pub hours: i32,
    pub minutes: i32,
    pub shift_repeat: ShiftRepeat,
    pub every_x: Option<i32>,
    pub note: Option<String>,
    pub on_call: bool,
}

#[derive(Debug, Insertable, Deserialize)]
#[table_name = "shifts"]
pub struct NewShift {
    pub supervisor_id: i32,
    pub employee_id: Option<i32>,
    pub year: i32,
    pub month: i32,
    pub day: i32,
    pub hour: i32,
    pub minute: i32,
    pub hours: i32,
    pub minutes: i32,
    pub shift_repeat: ShiftRepeat,
    pub every_x: Option<i32>,
    pub note: Option<String>,
    pub on_call: bool,
}

#[derive(Debug, Insertable, Deserialize)]
#[table_name = "vacations"]
pub struct NewVacation {
    pub supervisor_id: Option<i32>,
    pub employee_id: i32,
    pub approved: bool,
    pub start_year: i32,
    pub start_month: i32,
    pub start_day: i32,
    pub duration_days: Option<i32>,
    pub request_year: i32,
    pub request_month: i32,
    pub request_day: i32,
}

#[derive(
    Debug,
    Clone,
    Serialize,
    Deserialize,
    Identifiable,
    Associations,
    Queryable,
    AsChangeset,
)]
#[belongs_to(Employee)]
#[table_name = "vacations"]
pub struct Vacation {
    pub id: i32,
    pub supervisor_id: Option<i32>,
    pub employee_id: i32,
    pub approved: bool,
    pub start_year: i32,
    pub start_month: i32,
    pub start_day: i32,
    pub duration_days: Option<i32>,
    pub request_year: i32,
    pub request_month: i32,
    pub request_day: i32,
}
