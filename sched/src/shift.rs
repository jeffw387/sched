use chrono::{
    self,
    NaiveDateTime,
};

/// A structure representing a shift in the database
#[derive(
    Clone,
    Debug
)]
pub struct Shift {
    pub id: i32,
    pub employee_id: i32,
    pub start: NaiveDateTime,
    pub duration_hours: f32,
}
