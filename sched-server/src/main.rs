use actix::prelude::*;
use actix::Addr;
use actix_web::{
    server,
    App,
    AsyncResponder,
    HttpMessage,
    HttpRequest,
    HttpResponse,
    State,
};
use diesel::pg::PgConnection;
use diesel::r2d2::ConnectionManager;
use dotenv;
use futures::Future;
use sched_server::api;
use sched_server::db::Error as DbError;
use sched_server::db::{
    DbExecutor,
    Messages,
    Results,
};
use sched_server::employee::{
    Employee,
};
use sched_server::message::LoginInfo;
use sched_server::user::{
    NewUser,
    User,
};
use std::env;
use std::fs::File;
use std::io::prelude::*;

struct AppState {
    db: Addr<DbExecutor>,
}

const SESSION_COOKIE_KEY: &str = "session";

const ENV_DB_URL: &str = "DATABASE_URL";
const ENV_INDEX_BASE: &str = "INDEX_BASE";
const ENV_SERVER_PORT: &str = "SERVER_PORT";

type DbFuture =
    Future<Item = HttpResponse, Error = actix_web::Error>;
type DbRequest = (HttpRequest<AppState>, State<AppState>);

fn get_token(request: &HttpRequest<AppState>) -> String {
    match request.cookie(SESSION_COOKIE_KEY) {
        Some(token) => String::from(token.value()),
        None => String::new(),
    }
}

fn login((req, state): DbRequest) -> Box<DbFuture> {
    let db = state.db.clone();
    req.json()
        .from_err()
        .and_then(move |login_info: LoginInfo| {
            println!("Login Request: {:?}", login_info);
            db.send(Messages::Login(login_info))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn logout((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |user: User| {
            state
                .db
                .clone()
                .send(Messages::Logout(token, user))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn add_user((req, state): DbRequest) -> Box<DbFuture> {
    let db = state.db.clone();
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |login_info: LoginInfo| {
            db.send(Messages::AddUser(
                token,
                NewUser::new(login_info),
            ))
            .from_err()
            .and_then(handle_results)
            .responder()
        })
        .responder()
}

fn change_password(
    (req, state): DbRequest,
) -> Box<DbFuture> {
    // let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |change_password_info| {
            state
                .db
                .clone()
                .send(Messages::ChangePassword(
                    change_password_info,
                ))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn remove_user((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |user| {
            state
                .db
                .clone()
                .send(Messages::RemoveUser(token, user))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn get_settings((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    state
        .db
        .clone()
        .send(Messages::GetSettings(token))
        .from_err()
        .and_then(handle_results)
        .responder()
}

fn add_settings((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |new_settings| {
            state.db.clone()
                .send(Messages::AddSettings(token, new_settings))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn update_settings(
    (req, state): DbRequest,
) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |updated_settings| {
            state.db.clone()
                .send(Messages::UpdateSettings(token, updated_settings))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn get_employees((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    state
        .db
        .clone()
        .send(Messages::GetEmployees(token))
        .from_err()
        .and_then(handle_results)
        .responder()
}

fn get_employee((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |name| 
            state.db.clone()
            .send(Messages::GetEmployee(token, name))
            .from_err()
            .and_then(handle_results)
            .responder())
        .responder()
}

fn add_employee((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |new_employee| 
            state.db.clone()
            .send(Messages::AddEmployee(token, new_employee))
            .from_err()
            .and_then(handle_results)
            .responder())
        .responder()
}

fn update_employee((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |updated_employee| 
            state.db.clone()
            .send(Messages::UpdateEmployee(token, updated_employee))
            .from_err()
            .and_then(handle_results)
            .responder())
        .responder()
}

fn remove_employee((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |employee| {
            state.db.clone()
                .send(Messages::RemoveEmployee(token, employee))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn get_shifts((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |emp: Employee| {
            state
                .db
                .send(Messages::GetShifts(token, emp))
                .from_err()
                .and_then(handle_results)
        })
        .responder()
}

fn add_shift((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |new_shift| {
            state.db.clone()
                .send(Messages::AddShift(token, new_shift))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn update_shift((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |updated| {
            state.db.clone()
                .send(Messages::UpdateShift(token, updated))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn remove_shift((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |shift| {
            state.db.clone()
                .send(Messages::RemoveShift(token, shift))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn handle_results(result: Result<Results, DbError>)
    -> Result<HttpResponse, actix_web::Error> {
    match result {
        Ok(ok) => match ok {
            Results::GetSession(token) => 
                Ok(HttpResponse::Ok().json(token)),
            Results::GetUser(user) =>
                Ok(HttpResponse::Ok().json(user)),
            Results::GetSettingsVec(settings_vec) =>
                Ok(HttpResponse::Ok().json(settings_vec)),
            Results::GetSettings(settings) =>
                Ok(HttpResponse::Ok().json(settings)),
            Results::GetEmployeesVec(employees_vec) =>
                Ok(HttpResponse::Ok().json(employees_vec)),
            Results::GetEmployee(employee) =>
                Ok(HttpResponse::Ok().json(employee)),
            Results::GetShiftsVec(shifts_vec) =>
                Ok(HttpResponse::Ok().json(shifts_vec)),
            Results::GetShift(shift) =>
                Ok(HttpResponse::Ok().json(shift)),
            Results::Nothing => Ok(HttpResponse::Ok().finish())
        }
        Err(err) => Ok(HttpResponse::from_error(err.into()))
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
            .resource("/sched/index.js", |r| {
                r.get().f(index_js)
            })
            .resource(api::API_LOGIN_REQUEST, |r| {
                r.post().with_async(login)
            })
            .resource(api::API_LOGOUT_REQUEST, |r| {
                r.post().with_async(logout)
            })
            .resource(api::API_ADD_USER, |r| {
                r.post().with_async(add_user)
            })
            .resource(api::API_CHANGE_PASSWORD, |r| {
                r.post().with_async(change_password)
            })
            .resource(api::API_REMOVE_USER, |r| {
                r.post().with_async(remove_user)
            })
            .resource(api::API_GET_SETTINGS, |r| {
                r.post().with_async(get_settings)
            })
            .resource(api::API_ADD_SETTINGS, |r| {
                r.post().with_async(add_settings)
            })
            .resource(api::API_UPDATE_SETTINGS, |r| {
                r.post().with_async(update_settings)
            })
            .resource(api::API_GET_EMPLOYEES, |r| {
                r.post().with_async(get_employees)
            })
            .resource(api::API_GET_EMPLOYEE, |r| {
                r.post().with_async(get_employee)
            })
            .resource(api::API_ADD_EMPLOYEE, |r| {
                r.post().with_async(add_employee)
            })
            .resource(api::API_UPDATE_EMPLOYEE, |r| {
                r.post().with_async(update_employee)
            })
            .resource(api::API_REMOVE_EMPLOYEE, |r| {
                r.post().with_async(remove_employee)
            })
            .resource(api::API_GET_SHIFTS, |r| {
                r.post().with_async(get_shifts)
            })
            .resource(api::API_ADD_SHIFT, |r| {
                r.post().with_async(add_shift)
            })
            .resource(api::API_UPDATE_SHIFT, |r| {
                r.post().with_async(update_shift)
            })
            .resource(api::API_REMOVE_SHIFT, |r| {
                r.post().with_async(remove_shift)
            })
    })
    .bind(format!("localhost:{}", port))
    .unwrap()
    .start();

    let _ = sys.run();
}
