pub mod schema;
pub mod employee;
pub mod shift;

#[macro_use]
extern crate diesel;

use std::env;
use diesel::pg::PgConnection;
use diesel::prelude::*;
use dotenv::dotenv;

pub fn establish_connection() -> PgConnection {
    dotenv().ok();

    let db_url = env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set");
    PgConnection::establish(&db_url)
        .expect(&format!("Error connecting to {}", db_url))
}
