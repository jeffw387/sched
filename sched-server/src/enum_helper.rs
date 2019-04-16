use std::error::Error;

#[derive(Debug)]
pub struct StringError(pub String);

impl std::fmt::Display for StringError {
    fn fmt(
        &self,
        formatter: &mut std::fmt::Formatter,
    ) -> std::fmt::Result {
        write!(formatter, "Error: {}", self.0)
    }
}

impl Error for StringError {}

pub fn make_string_error(
    msg: &str,
) -> std::boxed::Box<
    (dyn std::error::Error
         + std::marker::Send
         + std::marker::Sync
         + 'static),
> {
    std::boxed::Box::new(StringError(String::from(msg)))
}

macro_rules! enum_to_sql {
    ($enum_type:ty) => {
        impl diesel::serialize::ToSql<Text, diesel::pg::Pg>
            for $enum_type
        {
            fn to_sql<W: std::io::Write>(
                &self,
                out: &mut diesel::serialize::Output<
                    W,
                    diesel::pg::Pg,
                >,
            ) -> diesel::serialize::Result {
                write!(out, "{}", self).unwrap();
                Ok(diesel::serialize::IsNull::No)
            }
        }
    };
}

macro_rules! enum_from_sql {
    ($enum_type:ident) => {
        impl diesel::deserialize::FromSql<Text, diesel::pg::Pg> for $enum_type {
            fn from_sql(bytes: Option<&[u8]>) -> diesel::deserialize::Result<Self> {
                match bytes {
                    Some(sbytes) => {
                        let text_form = match std::str::from_utf8(sbytes) {
                            Ok(correct_utf8) => correct_utf8,
                            Err(_e) => {
                                "enum utf8 error"
                            }

                        };
                        $enum_type::from_str(text_form)
                            .map_err(|e| {
                                let msg = format!("{:?}", e);
                                $crate::enum_helper::make_string_error(&msg)
                            })
                    }
                    None => Err(std::boxed::Box::new(crate::enum_helper::StringError(String::from("enum_from_sql: bytes empty!"))))
                }
            }
        }
    };
}
