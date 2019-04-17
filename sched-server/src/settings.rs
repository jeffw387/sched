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

enum_to_sql!(HourFormat);
enum_from_sql!(HourFormat);

enum_to_sql!(LastNameStyle);
enum_from_sql!(LastNameStyle);

enum_to_sql!(ViewType);
enum_from_sql!(ViewType);

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
    pub user_id: i32,
    pub view_type: ViewType,
    pub hour_format: HourFormat,
    pub last_name_style: LastNameStyle,
    pub view_year: i32,
    pub view_month: i32,
    pub view_day: i32,
    pub view_employees: Vec<i32>
}

#[derive(Serialize, Deserialize, Debug, Insertable)]
#[table_name = "settings"]
pub struct NewSettings {
    pub user_id: i32,
    pub view_type: ViewType,
    pub hour_format: HourFormat,
    pub last_name_style: LastNameStyle,
    pub view_year: i32,
    pub view_month: i32,
    pub view_day: i32,
    pub view_employees: Vec<i32>
}
