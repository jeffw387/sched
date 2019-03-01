pub mod models;
pub mod schema;

#[macro_use]
extern crate diesel;

use self::models::{
    Employee,
    NewEmployee,
};
use diesel::associations::*;
use diesel::pg::PgConnection;
use diesel::prelude::*;
use dotenv::dotenv;
use std::{
    env,
    result,
};

pub fn establish_connection() -> PgConnection {
    dotenv().ok();

    let db_url = env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set");
    PgConnection::establish(&db_url)
        .expect(&format!("Error connecting to {}", db_url))
}

pub fn add_employee<'a>(
    conn: &PgConnection,
    new_employee: NewEmployee<'a>,
) -> Employee {
    use schema::employees::dsl::*;

    diesel::insert_into(employees::table())
        .values(&new_employee)
        .get_result(conn)
        .expect("Error adding employee!")
}
