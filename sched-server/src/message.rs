use serde::{
    Deserialize,
    Serialize,
};

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct LoginInfo {
    pub email: String,
    pub password: String,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct ChangePasswordInfo {
    pub old_password: String,
    pub new_password: String,
}

pub struct Settings {}
