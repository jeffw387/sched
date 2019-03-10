use crate::schema::users;
use crypto::pbkdf2 as crypt;
use diesel::prelude::*;
use std::fmt::{
    Debug,
    Formatter,
};

/// Represents a user in the database
#[derive(Clone, Identifiable, Queryable, Debug)]
pub struct User {
    pub id: i32,
    pub name: String,
    pub password_hash: String,
}

#[derive(Clone, Insertable)]
#[table_name = "users"]
struct NewUser {
    name: String,
    password_hash: String,
}

impl NewUser {
    fn new(name: String, password: String) -> NewUser {
        NewUser {
            name,
            password_hash: crypt::pbkdf2_simple(
                &password, 1,
            )
            .expect("Failed to hash password!"),
        }
    }
}

/// Add a new user to the database
pub fn add_user(
    conn: &PgConnection,
    user_name: String,
    password: String,
) -> std::result::Result<User, Error> {
    match diesel::insert_into(users::table)
        .values(NewUser::new(user_name, password))
        .get_result(conn)
    {
        Ok(r) => Ok(r),
        Err(e) => Err(Error::Dsl(e)),
}
}

/// User-related error codes
pub enum Error {
    NotFound,
    WrongPassword,
    Dsl(diesel::result::Error),
}

impl Debug for Error {
    fn fmt(&self, f: &mut Formatter) -> std::fmt::Result {
        match self {
            Error::NotFound => {
                write!(f, "User was not found")
            }
            Error::WrongPassword => {
                write!(
                    f,
                    "The password given doesn't match"
                )
            }
            Error::Dsl(err) => err.fmt(f),
        }
    }
}

/// Return the user with the given name, or an error
pub fn get_user(
    conn: &PgConnection,
    name_find: &str,
) -> std::result::Result<User, Error> {
    use self::users::dsl::*;
    match users
        .filter(name.eq(name_find))
        .first::<User>(conn)
    {
        Ok(user) => Ok(user),
        Err(err) => Err(Error::Dsl(err)),
    }
}
    }
}

/// Remove the user with the given name if they exist
pub fn remove_user(conn: &PgConnection, name_find: &str) {
    match get_user(conn, name_find) {
        Ok(found) => {
            let _ = diesel::delete(&found).execute(conn);
        }
        Err(_) => (),
    }
}

impl User {
    /// Ensure that the given password matches
    /// the user's stored password
    pub fn check_password(
        &self,
        password: &str,
    ) -> std::result::Result<bool, &'static str> {
        crypt::pbkdf2_check(&password, &self.password_hash)
    }

    /// Given the old password matches, update the user
    /// to the new password
    pub fn change_password(
        &self,
        conn: &PgConnection,
        old_password: &str,
        new_password: &str,
    ) -> std::result::Result<(), Error> {
        match crypt::pbkdf2_check(
            &old_password,
            &self.password_hash,
        ) {
            Ok(pw_match) => {
                match pw_match {
                    true => {
                        return Err(Error::WrongPassword);
                    }
                    false => (),
                }
            }
            Err(err) => {
                panic!(err);
            }
        }
        let new_hash =
            crypt::pbkdf2_simple(new_password, 1);
        let _ = diesel::update(self)
            .set(
                users::password_hash.eq(new_hash.expect(
                    "Error creating password hash",
                )),
            )
            .execute(conn);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn user_test() {
        let test_name = String::from("jeffw");
        let test_pw = String::from("password123");
        let conn = crate::establish_connection();
        add_user(&conn, test_name.clone(), test_pw.clone());

        let found_user = get_user(&conn, &test_name)
            .expect("Error finding user!");
        assert_eq!(test_name, found_user.name);

        assert!(
            found_user.check_password(&test_pw).unwrap()
        );

        remove_user(&conn, &test_name);
    }
}
