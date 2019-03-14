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

#[derive(Clone, Debug)]
pub struct NewEmployee {
    name: Name,
    phone_number: Option<String>,
}

impl NewEmployee {
    pub fn new(
        name: Name,
        phone_number: Option<String>,
    ) -> NewEmployee {
        NewEmployee { name, phone_number }
    }
}