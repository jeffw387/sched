pub struct LoginInfo {
    pub username: String,
    pub password: String,
}

pub struct Settings {}

pub struct LoginRequest(LoginInfo);
