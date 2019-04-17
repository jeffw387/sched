use chrono::Datelike;
use chrono::Timelike;

pub fn now() -> DateTime {
    let chrono_now = chrono::Local::now();
    (
        chrono_now.year(),
        chrono_now.month() as i32,
        chrono_now.day() as i32,
        chrono_now.hour() as i32,
        chrono_now.minute() as i32,
    )
}

pub fn now_plus_hours(hours: u32) -> DateTime {
    let n = now();
    let mut days = n.2;
    let mut hours = hours as i32 + n.3;
    loop {
        use std::cmp::Ordering::Greater;
        match hours.cmp(&23) {
            Greater => {
                hours -= 24;
                days += 1;
            }
            _ => return (n.0, n.1, days, hours, n.4),
        }
    }
}

pub type DateTime = (i32, i32, i32, i32, i32);
