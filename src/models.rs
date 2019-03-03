use crate::schema::{employees, shifts};
use chrono::{
    self,
    NaiveDate,
    NaiveTime
};
use diesel::deserialize::Queryable;

#[derive(Clone, Debug, Insertable)]
#[table_name = "shifts"]
pub struct NewShift {
    pub employee_id: i32,
    pub start_date: NaiveDate,
    pub start_time: NaiveTime,
    pub duration_hours: f32,
}

impl NewShift {
    pub fn new(employee: &Employee, start_date: NaiveDate, start_time: NaiveTime, duration_hours: f32) -> NewShift {
        NewShift {
            employee_id: employee.id,
            start_date,
            start_time,
            duration_hours
        }
    }
    }
}

#[derive(Insertable, Clone, Debug, PartialEq)]
#[table_name = "employees"]
pub struct Name {
    pub first: String,
    pub last: String,
}

#[derive(Identifiable, Debug, Clone)]
pub struct Employee {
    pub id: i32,
    pub name: Name,
    pub phone_number: Option<String>,
}

impl Queryable<employees::SqlType, diesel::pg::Pg> for Employee {
    type Row = (i32, String, String, Option<String>);

    fn build(row: Self::Row) -> Self {
        Employee {
            id: row.0,
            name: Name { first: row.1, last: row.2 },
            phone_number: row.3,
        }
    }
}

#[derive(Insertable, Clone, Debug)]
#[table_name = "employees"]
pub struct NewEmployee {
    #[diesel(embed)]
    pub name: Name,
    pub phone_number: Option<String>,
}

impl NewEmployee {
    pub fn new(
        name: Name,
        phone_number: Option<String>,
    ) -> NewEmployee {
        NewEmployee { name, phone_number }
    }
}
