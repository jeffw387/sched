//! Everything related to web token handling

use actix_web::{
    HttpResponse,
    ResponseError,
};
use failure::Fail;
use jsonwebtoken::{
    decode,
    encode,
    Header,
    Validation,
};
use serde_derive::{
    Deserialize,
    Serialize,
};
use uuid::Uuid;

const SECRET: &[u8] = b"my_secret";

#[derive(Debug, Fail)]
/// Token handling related errors
pub enum TokenError {
    #[fail(display = "unable to create session token")]
    /// Session token creation failed
    Create,

    #[fail(display = "unable to verify session token")]
    /// Session token verification failed
    Verify,
}

impl ResponseError for TokenError {
    fn error_response(&self) -> HttpResponse {
        match self {
            TokenError::Create => {
                HttpResponse::InternalServerError().into()
            }
            TokenError::Verify => {
                HttpResponse::Unauthorized().into()
            }
        }
    }
}

#[derive(Deserialize, Serialize)]
/// A web token
pub struct Token {
    /// The subject of the token
    sub: String,

    /// The exipration date of the token
    exp: u64,

    /// The issued at field
    iat: u64,

    /// The token id
    jti: String,
}

impl Token {
    /// Create a new default token for a given username
    pub fn create(
        username: &str,
    ) -> Result<String, TokenError> {
        const DEFAULT_TOKEN_VALIDITY: u64 = 3600;
        use std::time::{
            SystemTime,
            UNIX_EPOCH,
        };
        let current_time = match SystemTime::now()
            .duration_since(UNIX_EPOCH)
        {
            Ok(current_time) => current_time.as_secs(),
            Err(e) => panic!(e),
        };
        let claim = Token {
            sub: username.to_owned(),
            exp: current_time + DEFAULT_TOKEN_VALIDITY,
            iat: current_time,
            jti: Uuid::new_v4().to_string(),
        };
        encode(&Header::default(), &claim, SECRET)
            .map_err(|_| TokenError::Create)
    }

    /// Verify the validity of a token and get a new one
    pub fn verify(
        token: &str,
    ) -> Result<String, TokenError> {
        let data = decode::<Token>(
            token,
            SECRET,
            &Validation::default(),
        )
        .map_err(|_| TokenError::Verify)?;
        Self::create(&data.claims.sub)
    }
}
