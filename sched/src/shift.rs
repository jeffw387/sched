use chrono::{
    self,
    NaiveDateTime,
};

#[derive(Debug)]
pub struct NewShift {
    employee_id: i32,
    start: NaiveDateTime,
    duration_hours: f32,
}

impl NewShift {
    pub fn new(
        employee_id: i32,
        start: NaiveDateTime,
        duration_hours: f32,
    ) -> NewShift {
        NewShift { employee_id, start, duration_hours }
    }
}

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
