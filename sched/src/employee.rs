use std::hash::{Hash, Hasher};

/// Employee's first and last names as Strings
#[derive(Clone, Debug)]
pub struct Name {
    pub first: String,
    pub last: String,
}

/// A structure mapping to an employee in the database
#[derive(Debug, Clone)]
pub struct Employee {
    pub id: i32,
    pub name: Name,
    pub phone_number: Option<String>,
}

impl Hash for Employee {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.id.hash(state)
    }
}

impl PartialEq for Employee {
    fn eq(&self, other: &Employee) -> bool {
        self.id == other.id
    }
}
impl Eq for Employee {}