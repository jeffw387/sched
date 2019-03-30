use super::schema::users;
use super::schema::sessions;
use crypto::pbkdf2 as crypt;
use diesel::pg::PgConnection;
use diesel::prelude::*;
use super::message::LoginInfo;
use std::fmt::{
    Debug,
    Formatter,
};
use serde::{Serialize, Deserialize};

#[derive(Clone, Debug, Insertable)]
#[table_name = "users"]
struct NewUser {
    email: String,
    password_hash: String,
}

impl NewUser {
    fn new(login_info: LoginInfo) -> NewUser {
        let new_user = NewUser {
            email: login_info.email,
            password_hash: crypt::pbkdf2_simple(
                &login_info.password,
                1,
            )
            .expect("Failed to hash password!"),
        };
        println!("NewUser created: {:#?}", new_user);
        new_user
    }
}

#[derive(Identifiable, Queryable)]
pub struct User {
    pub id: i32,
    pub email: String,
    pub password_hash: String,
}

/// Add a new user to the database
pub fn add_user(
    conn: &PgConnection,
    user_name: String,
    password: String,
) -> std::result::Result<User, Error> {
    println!("add_user(conn, {}, {})", user_name, password);
    match diesel::insert_into(users::table)
        .values(NewUser::new(LoginInfo {
            email: user_name,
            password,
        }))
        .get_result(conn)
    {
        Ok(r) => {
            println!("Successfully added user.");
            Ok(r)
        }
        Err(e) => {
            println!("Error adding user: {:?}", e);
            Err(Error::Dsl(e))
        }
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
        .filter(email.eq(name_find))
        .first::<User>(conn)
    {
        Ok(user) => Ok(user),
        Err(err) => match err {
            diesel::result::Error::NotFound => {
                Err(Error::NotFound)
            }
            other_err => Err(Error::Dsl(other_err))
        }
    }
}

/// Get all users in database
pub fn get_users(
    conn: &PgConnection,
) -> std::result::Result<Vec<User>, Error> {
    use self::users::dsl::*;
    match users.load::<User>(conn) {
        Ok(user_vec) => Ok(user_vec),
        Err(e) => Err(Error::Dsl(e)),
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

#[derive(Insertable, Debug)]
#[table_name="sessions"]
struct NewSession {
    user_id: i32,
    year: i32,
    month: i32,
    day: i32,
    hour: i32,
    hours: i32
}

#[derive(Debug, Serialize, Deserialize, Queryable)]
struct Session {
    id: i32,
    user_id: i32,
    year: i32,
    month: i32,
    day: i32,
    hour: i32,
    hours: i32
}

impl Session {
    fn encrypt(&self) -> std::io::Result<String> {
        let json = serde_json::to_string(&self)?;
        crypt::pbkdf2_simple(&json, 1)
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

// #[cfg(test)]
// mod tests {
//     use super::*;
//     #[test]
//     fn user_test() {
//         let test_name = String::from("jeffw");
//         let test_pw = String::from("password123");
//         let conn = crate::establish_connection();
//         let _user = add_user(
//             &conn,
//             test_name.clone(),
//             test_pw.clone(),
//         );

//         let found_user = get_user(&conn, &test_name)
//             .expect("Error finding user!");
//         assert_eq!(test_name, found_user.name);

//         assert!(
//             found_user.check_password(&test_pw).unwrap()
//         );

//         remove_user(&conn, &test_name);
//     }
// }
