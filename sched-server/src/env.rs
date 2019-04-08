use std::env;
use dotenv;

pub fn get_env(key: &str) -> String {
    dotenv::dotenv().ok();

    env::vars()
        .find(|(skey, _)| key == skey)
        .expect(&format!(
            "Can't find environment variable {}!",
            key
        ))
        .1
}

pub fn args() -> env::Args {
    env::args()
}