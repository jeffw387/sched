use chrono::{
    self,
    NaiveDate,
    NaiveTime,
};

fn main() {
    let s1_start_date = NaiveDate::from_ymd(2019, 3, 23);
    let s1_start_time = NaiveTime::from_hms(7, 0, 0);
    let s1_dur = chrono::Duration::hours(12);
    println!(
        "The shift starts at {} and lasts {} hours.",
        s1_start_date.and_time(s1_start_time),
        s1_dur.num_hours()
    );
}
