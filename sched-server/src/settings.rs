use super::schema::per_employee_settings;
use super::schema::settings;

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
    Hour12,
    Hour24,
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
    FullName,
    FirstInitial,
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
pub enum ViewType {
    Month,
    Week,
    Day,
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
}

enum_to_sql!(HourFormat);
enum_from_sql!(HourFormat);

enum_to_sql!(LastNameStyle);
enum_from_sql!(LastNameStyle);

enum_to_sql!(ViewType);
enum_from_sql!(ViewType);

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
#[table_name = "settings"]
pub struct Settings {
    pub id: i32,
    pub employee_id: i32,
    pub name: String,
    pub view_type: ViewType,
    pub hour_format: HourFormat,
    pub last_name_style: LastNameStyle,
    pub view_year: i32,
    pub view_month: i32,
    pub view_day: i32,
    pub view_employees: Vec<i32>,
    pub show_minutes: bool,
}

impl From<Settings> for NewSettings {
    fn from(settings: Settings) -> Self {
        NewSettings {
            employee_id: settings.employee_id,
            name: settings.name,
            view_type: settings.view_type,
            hour_format: settings.hour_format,
            last_name_style: settings.last_name_style,
            view_year: settings.view_year,
            view_month: settings.view_month,
            view_day: settings.view_day,
            view_employees: settings.view_employees,
            show_minutes: settings.show_minutes,
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Insertable)]
#[table_name = "settings"]
pub struct NewSettings {
    pub employee_id: i32,
    pub name: String,
    pub view_type: ViewType,
    pub hour_format: HourFormat,
    pub last_name_style: LastNameStyle,
    pub view_year: i32,
    pub view_month: i32,
    pub view_day: i32,
    pub view_employees: Vec<i32>,
    pub show_minutes: bool,
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
#[table_name = "per_employee_settings"]
pub struct PerEmployeeSettings {
    pub id: i32,
    pub settings_id: i32,
    pub employee_id: i32,
    pub color: EmployeeColor,
}

#[derive(Deserialize, Debug, Insertable, Clone)]
#[table_name = "per_employee_settings"]
pub struct NewPerEmployeeSettings {
    pub settings_id: i32,
    pub employee_id: i32,
    pub color: EmployeeColor,
}

impl From<PerEmployeeSettings> for NewPerEmployeeSettings {
    fn from(per_employee: PerEmployeeSettings) -> Self {
        NewPerEmployeeSettings {
            settings_id: per_employee.settings_id,
            employee_id: per_employee.employee_id,
            color: per_employee.color,
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct CombinedSettings {
    pub settings: Settings,
    pub per_employee: Vec<PerEmployeeSettings>,
}
