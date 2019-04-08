use sched_server::db;
use getopts::Options;
use crypto::pbkdf2 as crypt;
use std::result::Result;
use diesel::pg::PgConnection;
use sched_server::api::*;
use sched_server::env;
use diesel::connection::Connection;
use sched_server::schema::users;
use sched_server::user::{NewUser, UserLevel};
use sched_server::message::LoginInfo;
use diesel::prelude::*;

enum Error {
    ConnectionFailure,
    UserAlreadyExists,
}

fn add_user(email: String, password: String, level: UserLevel) {
    let db_url = env::get_env(ENV_DB_URL);
    let conn = PgConnection::establish(&db_url)
        .unwrap_or_else(|_| {println!("Connection failure!"); std::process::exit(1);});
    let login_info = LoginInfo {
        email: email.clone(),
        password
    };
    let new_user = NewUser::new(login_info, level);
    diesel::insert_into(users::table)
        .values(new_user)
        .execute(&conn)
        .map(|_| {println!("Successfully added user {}!", &email);})
        .map_err(|_| {println!("User insert error!");});
}

fn main() {
    let args: Vec<String> = env::args().collect();
    // let program = args[0].clone();
    let mut opts = Options::new();
    opts.optflag("a", "add", "Add");
    opts.optflag("u", "user", "User");
    opts.optopt("l", "level", "User Access Level: Read, Supervisor, Admin", "LEVEL");
    opts.optopt("e", "email", "Set the email address", "EMAIL@DOMAIN.COM");
    opts.optopt("p", "password", "Set the password", "PASSWORD");
    let matches = match opts.parse(&args[1..]) {
        Ok(m) => m,
        Err(e) => panic!(e.to_string())
    };
    if matches.opt_present("u") {
        if matches.opt_present("a") {
            let level = match matches.opt_str("l")
                .unwrap_or(String::from("Read"))
                .as_ref() {
                    "Supervisor" => UserLevel::Supervisor,
                    "Admin" => UserLevel::Admin,
                    _ => UserLevel::Read,
                };
            let email = matches.opt_str("e")
                .unwrap_or_else(|| {
                    println!("Need to use email option to add a user");
                    std::process::exit(0);});
            let password = matches.opt_str("p")
                .unwrap_or_else(|| {
                    println!("Need to use password option to add a user");
                    std::process::exit(0);});
            add_user(email, password, level);
                }
            }
    }