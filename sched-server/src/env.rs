use dotenv;
use std::env;

pub fn get_env(key: &str) -> String {
    dotenv::dotenv().ok();

    env::vars()
        .find(|(skey, _)| key == skey)
        .unwrap_or_else(|| {
            panic!(
                "Can't find environment variable {}!",
                key
            )
        })
        .1
}

pub fn args() -> env::Args {
    env::args()
}
