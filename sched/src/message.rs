#[derive(Clone, Debug, Default)]
pub struct LoginInfo {
    pub email: String,
    pub password: String,
}

pub struct Settings {}

pub struct LoginRequest(LoginInfo);
