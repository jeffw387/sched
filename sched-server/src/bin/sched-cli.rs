use chrono::{
    DateTime,
    Utc,
};
use crypto::pbkdf2 as crypt;
use diesel::connection::Connection;
use diesel::pg::PgConnection;
use diesel::prelude::*;
use getopts::Options;
use sched_server::api::*;
use sched_server::config::{
    Config,
    EmployeeColor,
    HourFormat,
    LastNameStyle,
    NewConfig,
};
use sched_server::db;
use sched_server::employee::{
    Employee,
    EmployeeLevel,
    Name,
    NewEmployee,
};
use sched_server::env;
use sched_server::message::LoginInfo;
use sched_server::schema::configs;
use sched_server::schema::employees;
use std::result::Result;

enum Error {
    ConnectionFailure,
    EmployeeAlreadyExists,
}

fn add_employee(
    email: String,
    password: String,
    level: EmployeeLevel,
    name: Name,
    phone_number: Option<String>,
) {
    let db_url = env::get_env("DATABASE_URL");
    let conn = PgConnection::establish(&db_url)
        .unwrap_or_else(|_| {
            println!("Connection failure!");
            std::process::exit(1);
        });
    let login_info =
        LoginInfo { email: email.clone(), password };
    let new_employee = NewEmployee::new(
        login_info,
        None,
        level,
        name.first,
        name.last,
        phone_number,
        EmployeeColor::Blue,
    );
    let inserted_employee =
        diesel::insert_into(employees::table)
            .values(new_employee)
            .get_result::<Employee>(&conn)
            .map_err(|_| {
                println!("Employee insert error!");
            })
            .unwrap();
    let new_config = NewConfig {
        employee_id: inserted_employee.id,
        config_name: String::from("Default"),
        hour_format: HourFormat::H12,
        last_name_style: LastNameStyle::Hidden,
        view_date: Utc::now(),
        view_employees: vec![],
        show_minutes: true,
        show_shifts: true,
        show_vacations: false,
        show_call_shifts: false,
        show_disabled: false,
    };
    let inserted_config =
        diesel::insert_into(configs::table)
            .values(new_config)
            .get_result::<Config>(&conn)
            .map_err(|_| {
                println!("Error inserting new settings!")
            })
            .unwrap();
    let _ = diesel::update(&inserted_employee.clone())
        .set(employees::active_config.eq(inserted_config.id))
        .execute(&conn)
        .expect("Error updating employee with new default settings!");
}

fn main() {
    let args: Vec<String> = env::args().collect();
    // let program = args[0].clone();
    let mut opts = Options::new();
    opts.optflag("a", "add", "Add");
    opts.optflag("", "employee", "Employee");
    opts.optopt(
        "l",
        "level",
        "Employee Access Level: Read, Supervisor, Admin",
        "LEVEL",
    );
    opts.optopt(
        "e",
        "email",
        "Set the email address",
        "EMAIL@DOMAIN.COM",
    );
    opts.optopt(
        "p",
        "password",
        "Set the password",
        "PASSWORD",
    );
    opts.optopt(
        "",
        "first",
        "Employee's first name",
        "FIRSTNAME",
    );
    opts.optopt(
        "",
        "last",
        "Employee's last name",
        "LASTNAME",
    );
    opts.optopt(
        "",
        "phone",
        "Employee's phone number, optional",
        "PHONE",
    );
    let matches = match opts.parse(&args[1..]) {
        Ok(m) => m,
        Err(e) => panic!(e.to_string()),
    };
    if matches.opt_present("employee") {
        if matches.opt_present("a") {
            let level = match matches
                .opt_str("l")
                .unwrap_or(String::from("Read"))
                .as_ref()
            {
                "Supervisor" => EmployeeLevel::Supervisor,
                "Admin" => EmployeeLevel::Admin,
                _ => EmployeeLevel::Read,
            };
            let email = matches.opt_str("e")
                .unwrap_or_else(|| {
                    println!("Need to use email option to add a employee");
                    std::process::exit(0);});
            let password = matches.opt_str("p")
                .unwrap_or_else(|| {
                    println!("Need to use password option to add a employee");
                    std::process::exit(0);});
            let first = matches.opt_str("first")
                .unwrap_or_else(|| {
                    println!("Need to provide first and last name for employee");
                    std::process::exit(0);
                });
            let last = matches.opt_str("last")
                .unwrap_or_else(|| {
                    println!("Need to provide first and last name for employee");
                    std::process::exit(0);
                });
            let name = Name { first, last };
            let phone_number = matches.opt_str("phone");

            add_employee(
                email,
                password,
                level,
                name,
                phone_number,
            );
        }
    }
}
