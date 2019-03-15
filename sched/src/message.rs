use serde::{Serialize, Deserialize};

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct LoginInfo {
    pub email: String,
    pub password: String,
}

pub struct Settings {}

