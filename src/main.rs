use chrono::{
    self,
    NaiveDate,
};
// use chrono::prelude::*;
use sched;
use sched::models::{
    Employee,
    NewEmployee,
    Shift,
};

extern crate diesel;
use self::diesel::prelude::*;

fn main() {
    let s1_start =
        NaiveDate::from_ymd(2019, 3, 23).and_hms(7, 0, 0);
    let s1_dur = chrono::Duration::hours(12);
    let s1 = Shift::new(s1_start, s1_dur);
    println!(
        "The shift starts at {} and lasts {} hours.",
        s1.start,
        s1.duration.num_hours()
    );

    let connection = sched::establish_connection();

    let _new_fox = sched::add_employee(
        &connection,
        NewEmployee::new(
            "Bob",
            "Jones",
            Some("222-123-4567"),
        ),
    );

    let mes = employees
        .filter(first.eq("Jeff"))
        .load::<Employee>(&connection)
        .expect("Error loading me");
    for me in mes {
        println!("Me = {} {}", me.first, me.last);
    }
}
