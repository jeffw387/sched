use chrono::{
    self,
    Duration,
    NaiveDateTime,
};

pub struct Shift {
    pub start: NaiveDateTime,
    pub duration: Duration,
}

impl Shift {
    pub fn new(
        start: NaiveDateTime,
        duration: Duration,
    ) -> Shift {
        Shift { start, duration }
    }
}

#[derive(Insertable, Clone, Debug, PartialEq)]
#[table_name = "employees"]
pub struct Name {
    pub first: String,
    pub last: String
}

#[derive(Identifiable, Debug, Clone)]
pub struct Employee {
    pub id: i32,
    pub name: Name,
    pub phone_number: Option<String>,
}

type DB = diesel::pg::Pg;
impl Queryable<employees::SqlType, DB> for Employee {
    type Row = (i32, String, String, Option<String>);

    fn build(row: Self::Row) -> Self {
        Employee {
            id: row.0,
            name: Name {
                first: row.1,
                last: row.2
            },
            phone_number: row.3
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
