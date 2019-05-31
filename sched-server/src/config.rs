use super::schema::per_employee_configs;
use super::schema::configs;
use chrono::{DateTime, Utc};
use diesel::sql_types::Text;
use serde::{
    Deserialize,
    Serialize,
};
use std::str::FromStr;
use strum_macros::{
    AsRefStr,
    Display,
    EnumString,
};

#[derive(
    Debug,
    Serialize,
    Deserialize,
    AsExpression,
    FromSqlRow,
    EnumString,
    Display,
    AsRefStr,
    Clone,
)]
#[sql_type = "Text"]
pub enum HourFormat {
    H12,
    H24,
}

#[derive(
    Debug,
    Serialize,
    Deserialize,
    AsExpression,
    FromSqlRow,
    EnumString,
    Display,
    AsRefStr,
    Clone,
)]
#[sql_type = "Text"]
pub enum LastNameStyle {
    Full,
    Initial,
    Hidden,
}

#[derive(
    Debug,
    Serialize,
    Deserialize,
    AsExpression,
    FromSqlRow,
    EnumString,
    Display,
    AsRefStr,
    Clone,
)]
#[sql_type = "Text"]
pub enum CalendarView {
    Month,
    Week,
    Day,
    DayAlt,
}

#[derive(
    Debug,
    Serialize,
    Deserialize,
    AsExpression,
    FromSqlRow,
    EnumString,
    Display,
    AsRefStr,
    Clone,
)]
#[sql_type = "Text"]
pub enum EmployeeColor {
    Red,
    LightRed,
    Green,
    LightGreen,
    Blue,
    LightBlue,
    Yellow,
    LightYellow,
    Grey,
    LightGrey,
    Black,
    Brown,
    Purple,
}

enum_to_sql!(HourFormat);
enum_from_sql!(HourFormat);

enum_to_sql!(LastNameStyle);
enum_from_sql!(LastNameStyle);

enum_to_sql!(CalendarView);
enum_from_sql!(CalendarView);

enum_to_sql!(EmployeeColor);
enum_from_sql!(EmployeeColor);

#[derive(
    Serialize,
    Deserialize,
    Debug,
    Queryable,
    Identifiable,
    AsChangeset,
    Clone,
)]
#[table_name = "configs"]
pub struct Config {
    pub id: i32,
    pub employee_id: i32,
    pub config_name: String,
    pub hour_format: HourFormat,
    pub last_name_style: LastNameStyle,
    pub view_date: DateTime<Utc>,
    pub view_employees: Vec<i32>,
    pub show_minutes: bool,
    pub show_shifts: bool,
    pub show_vacations: bool,
    pub show_call_shifts: bool,
    pub show_disabled: bool,
}

#[derive(Serialize, Deserialize, Debug, Insertable, Clone)]
#[table_name = "configs"]
pub struct NewConfig {
    pub employee_id: i32,
    pub config_name: String,
    pub hour_format: HourFormat,
    pub last_name_style: LastNameStyle,
    pub view_date: DateTime<Utc>,
    pub view_employees: Vec<i32>,
    pub show_minutes: bool,
    pub show_shifts: bool,
    pub show_vacations: bool,
    pub show_call_shifts: bool,
    pub show_disabled: bool,
}

#[derive(
    Serialize,
    Deserialize,
    Debug,
    Queryable,
    Identifiable,
    AsChangeset,
    Clone,
)]
pub struct PerEmployeeConfig {
    pub id: i32,
    pub config_id: i32,
    pub employee_id: i32,
    pub color: EmployeeColor,
}

#[derive(Deserialize, Debug, Insertable, Clone)]
#[table_name = "per_employee_configs"]
pub struct NewPerEmployeeConfig {
    pub config_id: i32,
    pub employee_id: i32,
    pub color: EmployeeColor,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct CombinedConfig {
    pub config: Config,
    pub per_employee: Vec<PerEmployeeConfig>,
}
