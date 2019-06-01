use super::employee::Employee;
use super::schema::{
    shift_exceptions,
    shifts,
    vacations,
};
use diesel::sql_types::Text;
use std::str::FromStr;
use strum_macros::{
    Display,
    EnumString,
};

use chrono::{
    DateTime,
    Utc,
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
    pub start: DateTime<Utc>,
    pub end: DateTime<Utc>,
    pub repeat: ShiftRepeat,
    pub every_x: Option<i32>,
    pub note: Option<String>,
    pub on_call: bool,
}

#[derive(Debug, Insertable, Deserialize, Clone)]
#[table_name = "shifts"]
pub struct NewShift {
    pub supervisor_id: i32,
    pub employee_id: Option<i32>,
    pub start: DateTime<Utc>,
    pub end: DateTime<Utc>,
    pub repeat: ShiftRepeat,
    pub every_x: Option<i32>,
    pub note: Option<String>,
    pub on_call: bool,
}

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
#[table_name = "shift_exceptions"]
pub struct ShiftException {
    pub id: i32,
    pub shift_id: i32,
    pub date: DateTime<Utc>,
}

#[derive(Debug, Insertable, Deserialize, Clone)]
#[table_name = "shift_exceptions"]
pub struct NewShiftException {
    pub shift_id: i32,
    pub date: DateTime<Utc>,
}

#[derive(Debug, Insertable, Deserialize, Clone)]
#[table_name = "vacations"]
pub struct NewVacation {
    pub supervisor_id: Option<i32>,
    pub employee_id: i32,
    pub approved: bool,
    pub start: DateTime<Utc>,
    pub end: DateTime<Utc>,
    pub requested: DateTime<Utc>,
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
    pub start: DateTime<Utc>,
    pub end: DateTime<Utc>,
    pub requested: DateTime<Utc>,
}
