/// Represents a user in the database
#[derive(Clone, Debug)]
pub struct User {
    pub id: i32,
    pub name: String,
    pub password_hash: String,
}

#[derive(Clone, Debug)]
struct NewUser {
    name: String,
    password_hash: String,
}