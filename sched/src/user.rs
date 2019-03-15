use serde::{
    Deserialize,
    Serialize,
};

/// Represents a user in the database
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct User {
    pub id: i32,
    pub email: String,
    pub password_hash: String,
}
