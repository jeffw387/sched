use actix::prelude::*;
use actix::Addr;
use actix_web::http;
use actix_web::{
    // fs::StaticFiles,
    server,
    App,
    AsyncResponder,
    HttpMessage,
    HttpRequest,
    HttpResponse,
    State,
};
use chrono::Duration;
use cookie::SameSite;
use diesel::pg::PgConnection;
use diesel::r2d2::ConnectionManager;
use dotenv;
use futures::Future;
use sched_server::api;
use sched_server::message::LoginInfo;
use sched_server::db::{
    CreateUser,
    CreateUserResult,
    DbExecutor,
    GetEmployees,
    GetShifts,
    LoginRequest,
    LoginResult,
};
use std::env;
use std::fs::File;
use std::io::prelude::*;
use std::ops::Deref;

struct AppState {
    db: Addr<DbExecutor>,
}

const SESSION_KEY: &str = "session";
const SESSION_TEST_VALUE: &str = "";

const ENV_DB_URL: &str = "DATABASE_URL";
const ENV_INDEX_BASE: &str = "INDEX_BASE";
const ENV_SERVER_PORT: &str = "SERVER_PORT";

fn make_session(secure: bool) -> http::Cookie<'static> {
    http::Cookie::build(SESSION_KEY, SESSION_TEST_VALUE)
        .max_age(Duration::days(1))
        .domain("localhost")
        .http_only(true)
        .secure(secure)
        .same_site(SameSite::Strict)
        .finish()
}

type ImmediateResult =
    futures::Poll<HttpResponse, actix_web::Error>;

struct ImmediateResponse<F>
where
    F: Sized + FnOnce() -> HttpResponse + Copy,
{
    f: F,
}

impl<F> Future for ImmediateResponse<F>
where
    F: Sized + FnOnce() -> HttpResponse + Copy,
{
    type Item = HttpResponse;
    type Error = actix_web::Error;

    fn poll(&mut self) -> ImmediateResult {
        Ok(futures::Async::Ready((self.f)()))
    }
}

fn add_user(
    (req, state): (HttpRequest<AppState>, State<AppState>),
) -> Box<
    Future<Item = HttpResponse, Error = actix_web::Error>,
> {
    print_cookies(&req);
    let db = state.db.clone();
    req.json()
        .from_err()
        .and_then(move |login_info: LoginInfo| {
            db.send(CreateUser(login_info))
                .from_err()
                .and_then(
                    |create_result: CreateUserResult| {
                        match create_result {
                            Ok(()) => {
                                Ok(HttpResponse::Ok()
                                    .cookie(make_session(false))
                                    .finish())
                            }
                            Err(err) => Ok(
                                HttpResponse::Unauthorized(
                                )
                                .content_type("text/plain")
                                .body(format!("{:?}", err)),
                            ),
                        }
                    },
                )
                .responder()
        })
        .responder()
}

fn login_request(
    (req, state): (HttpRequest<AppState>, State<AppState>),
) -> Box<
    Future<Item = HttpResponse, Error = actix_web::Error>,
> {
    print_cookies(&req);
    let db = state.db.clone();
    req.json()
        .from_err()
        .and_then(move |login_info: LoginInfo| {
            println!("Login Request: {:?}", login_info);
            db.send(LoginRequest(login_info))
                .from_err()
                .and_then(|login_result: LoginResult| {
                    println!("Login Result: {:?}", login_result);
                    match login_result {
                        Ok(_token) => {
                            println!("Login result Ok");
                            Ok(HttpResponse::Ok()
                                .cookie(make_session(false))
                                .finish())
                        }
                        Err(_err) => {
                            println!("Login result error!");
                            Ok(HttpResponse::Unauthorized()
                                .finish())
                        }
                    }
                })
                .responder()
        })
        .responder()
}

// TODO: actually validate session
fn validate_session(
    cookie: Option<cookie::Cookie>,
    user_token: &str,
) -> bool {
    match cookie {
        None => false,
        Some(cookie) => user_token == cookie.value(),
    }
}

fn print_cookies(
    req: &HttpRequest<AppState>
) {
    match req.cookies() {
        Ok(cks) => {
            println!("Printing cookies:");
            for ck in cks.deref() {
                println!("Cookie: {:?}", ck);
            }
        }
        Err(err) => println!("Error getting cookies: {}", err)
    };
}

fn get_employees(
    (req, state): (HttpRequest<AppState>, State<AppState>),
) -> Box<
    Future<Item = HttpResponse, Error = actix_web::Error>,
> {
    print_cookies(&req);
    if validate_session(
        req.cookie(SESSION_KEY),
        SESSION_TEST_VALUE,
    ) {
        println!("Session validated!");
        state
            .db
            .send(GetEmployees {})
            .from_err()
            .and_then(|res| {
                match res {
                    Ok(emps) => {
                        Ok(HttpResponse::Ok().json(emps))
                    }
                    Err(e) => {
                        Ok(HttpResponse::from_error(
                            e.into(),
                        ))
                    }
                }
            })
            .responder()
    } else {
        println!("Session not validated!");
        Box::new(ImmediateResponse {
            f: || HttpResponse::Unauthorized().finish(),
        })
    }
}

fn get_shifts(
    (req, state): (HttpRequest<AppState>, State<AppState>),
) -> Box<
    Future<Item = HttpResponse, Error = actix_web::Error>,
> {
    print_cookies(&req);
    if validate_session(
        req.cookie(SESSION_KEY),
        SESSION_TEST_VALUE,
    ) {
        use sched_server::employee::Employee;
        req.json()
            .from_err()
            .and_then(move |emp: Employee| {
                state
                    .db
                    .send(GetShifts(emp))
                    .from_err()
                    .and_then(|res| {
                        match res {
                            Ok(shifts) => {
                                Ok(HttpResponse::Ok()
                                    .json(shifts))
                            }
                            Err(e) => Ok(
                                HttpResponse::from_error(
                                    e.into(),
                                ),
                            ),
                        }
                    })
            })
            .responder()
    } else {
        Box::new(ImmediateResponse {
            f: || HttpResponse::Unauthorized().finish(),
        })
    }
}

fn get_env(key: &str) -> String {
    env::vars()
        .find(|(skey, _)| key == skey)
        .expect(&format!(
            "Can't find environment variable {}!",
            key
        ))
        .1
}

fn load_static_js() -> String {
    let mut js_url = get_env(ENV_INDEX_BASE);
    js_url.push_str("/index.js");
    let static_js = File::open(js_url);
    match static_js {
        Ok(mut file) => {
            let mut result = String::new();
            match file.read_to_string(&mut result) {
                Ok(_) => {
                    println!("Loaded static js");
                    result
                }
                Err(e) => {
                    let msg = format!(
                        "Error reading from static resource: {:#?}", e
                    );
                    println!("{}", msg);
                    msg
                }
            }
        }
        Err(e) => {
            let msg = format!(
                "Error loading static resource: {:#?}",
                e
            );
            println!("{}", msg);
            msg
        }
    }
}

fn load_static_html() -> String {
    let mut index_url = get_env(ENV_INDEX_BASE);
    index_url.push_str("/index.html");
    let static_file = File::open(index_url);
    match static_file {
        Ok(mut file) => {
            let mut result = String::new();
            match file.read_to_string(&mut result) {
                Ok(_) => {
                    println!("Loaded static html");
                    result
                }
                Err(e) => {
                    let msg = format!(
                        "Error reading from static resource: {:#?}",
                        e
                    );
                    println!("{}", msg);
                    msg
                }
            }
        }
        Err(e) => {
            let msg = format!(
                "Error loading static resource: {:#?}",
                e
            );
            println!("{}", msg);
            msg
        }
    }
}

fn index(_: &HttpRequest<AppState>) -> HttpResponse {
    HttpResponse::Ok()
        .content_type("text/html")
        .body(load_static_html())
}

fn index_js(_: &HttpRequest<AppState>) -> HttpResponse {
    HttpResponse::Ok()
        .content_type("text/javascript")
        .body(load_static_js())
}

fn main() {
    dotenv::dotenv().ok();
    let sys = actix::System::new("database-system");
    let db_url = get_env(ENV_DB_URL);
    let port = get_env(ENV_SERVER_PORT);

    println!("database url: {}", db_url);
    let manager =
        ConnectionManager::<PgConnection>::new(db_url);

    let pool = r2d2::Pool::builder()
        .build(manager)
        .expect("Failed to create connection pool!");

    let addr = SyncArbiter::start(3, move || {
        DbExecutor(pool.clone())
    });
    if addr.connected() {
        println!("Successfully connected to database.");
    } else {
        println!("Failed to connect to database.");
    }

    server::HttpServer::new(move || {
        App::with_state(AppState { db: addr.clone() })
            .middleware(
                actix_web::middleware::Logger::default(),
            )
            .default_resource(|r| r.get().f(index))
            .resource(api::API_INDEX, |r| r.get().f(index))
            .resource("/sched/index.js", |r| r.get().f(index_js))
            .resource(api::API_LOGIN_REQUEST, |r| {
                r.post().with_async(login_request)
            })
            .resource(api::API_ADD_USER, |r| {
                r.post().with_async(add_user)
            })
            .resource(api::API_GET_EMPLOYEES, |r| {
                r.post().with_async(get_employees)
            })
            .resource(api::API_GET_SHIFTS, |r| {
                r.post().with_async(get_shifts)
            })
    })
    .bind(format!("localhost:{}", port))
    .unwrap()
    .start();

    let _ = sys.run();
}
