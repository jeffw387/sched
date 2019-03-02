use chrono::{
    self,
    NaiveDate,
};

use sched;
use sched::models::{
    Shift,
};

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
}
