use actix::prelude::*;
use actix::Addr;
use actix_web::{
    fs::NamedFile,
    server,
    App,
    AsyncResponder,
    HttpMessage,
    HttpRequest,
    HttpResponse,
    State,
};
use cookie::Cookie;
use diesel::pg::PgConnection;
use diesel::r2d2::ConnectionManager;
use futures::Future;
use sched_server::api::*;
use sched_server::db::Error as DbError;
use sched_server::db::{
    DbExecutor,
    Messages,
    Results,
};
use sched_server::env;
use sched_server::message::LoginInfo;

struct AppState {
    db: Addr<DbExecutor>,
}

const SESSION_COOKIE_KEY: &str = "session";

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
    println!("logout request received");
    let token = get_token(&req);
    state
        .db
        .clone()
        .send(Messages::Logout(token))
        .from_err()
        .and_then(handle_results)
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

fn default_settings(
    (req, state): DbRequest,
) -> Box<DbFuture> {
    let token = get_token(&req);
    state
        .db
        .send(Messages::DefaultSettings(token))
        .from_err()
        .and_then(handle_results)
        .responder()
}

fn add_settings((req, state): DbRequest) -> Box<DbFuture> {
    println!("add_settings");
    let token = get_token(&req);
    req.json()
        .map_err(|err| {
            println!("Error: {:?}", err);
            err
        })
        .from_err()
        .and_then(move |new_settings| {
            state
                .db
                .clone()
                .send(Messages::AddSettings(
                    token,
                    new_settings,
                ))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn copy_settings((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map_err(|err| {
            println!("Error: {:?}", err);
            err
        })
        .from_err()
        .and_then(move |original| {
            state.db.clone()
                .send(Messages::CopySettings(
                    token,
                    original
                ))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn set_default_settings(
    (req, state): DbRequest,
) -> Box<DbFuture> {
    println!("--set_default_settings");
    let token = get_token(&req);
    req.json()
        .map_err(|e| {
            println!("Error: {:?}", e);
            e
        })
        .from_err()
        .and_then(move |settings| {
            println!(
                "Successfully decoded json: {:?}",
                settings
            );
            state
                .db
                .clone()
                .send(Messages::SetDefaultSettings(
                    token, settings,
                ))
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
            state
                .db
                .clone()
                .send(Messages::UpdateSettings(
                    token,
                    updated_settings,
                ))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn remove_settings((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |settings| {
            state.db.clone()
                .send(Messages::RemoveSettings(token, settings))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn add_employee_settings((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map_err(|j| {
            eprintln!("Json error: {:?}", j);
            j
        })
        .from_err()
        .and_then(move |new_settings| {
            state.db.clone()
                .send(Messages::AddEmployeeSettings(token, new_settings))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn update_employee_settings((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map_err(|j| {
            eprintln!("Json error: {:?}", j);
            j
        })
        .from_err()
        .and_then(move |settings| {
            state.db.clone()
                .send(Messages::UpdateEmployeeSettings(token, settings))
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
        .and_then(move |name| {
            state
                .db
                .clone()
                .send(Messages::GetEmployee(token, name))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn add_employee((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |new_employee| {
            state
                .db
                .clone()
                .send(Messages::AddEmployee(
                    token,
                    new_employee,
                ))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn update_employee(
    (req, state): DbRequest,
) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |updated_employee| {
            state
                .db
                .clone()
                .send(Messages::UpdateEmployee(
                    token,
                    updated_employee,
                ))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn remove_employee(
    (req, state): DbRequest,
) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |employee| {
            state
                .db
                .clone()
                .send(Messages::RemoveEmployee(
                    token, employee,
                ))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn get_shifts((req, state): DbRequest) -> Box<DbFuture> {
    println!("get_shifts");
    let token = get_token(&req);
    state
        .db
        .send(Messages::GetShifts(token))
        .from_err()
        .and_then(handle_results)
        .responder()
}

fn add_shift((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .from_err()
        .and_then(move |new_shift| {
            state
                .db
                .clone()
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
            state
                .db
                .clone()
                .send(Messages::UpdateShift(token, updated))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn remove_shift((req, state): DbRequest) -> Box<DbFuture> {
    println!("remove_shift");
    let token = get_token(&req);
    req.json()
        .map_err(|j| {
            eprintln!("Json error: {:?}", j);
            j
        })
        .from_err()
        .and_then(move |shift| {
            state
                .db
                .clone()
                .send(Messages::RemoveShift(token, shift))
                .map_err(|r_err| {
                    eprintln!("Remove Shift error: {:?}", r_err);
                    r_err
                })
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn handle_results(
    result: Result<Results, DbError>,
) -> Result<HttpResponse, actix_web::Error> {
    match result {
        Ok(ok) => {
            match ok {
                Results::GetSession(token) => {
                    Ok(HttpResponse::Ok()
                        .cookie(
                            Cookie::build(
                                SESSION_COOKIE_KEY,
                                token.contents,
                            )
                            .http_only(true)
                            .secure(false)
                            .finish(),
                        )
                        .finish())
                }
                Results::GetUser(user) => {
                    Ok(HttpResponse::Ok().json(user))
                }
                Results::GetCombinedSettings(combined) => {
                    Ok(HttpResponse::Ok().json(combined))
                }
                Results::GetSettings(settings) => {
                    Ok(HttpResponse::Ok().json(settings))
                }
                Results::GetSettingsID(id) => {
                    Ok(HttpResponse::Ok().json(id))
                }
                Results::GetEmployeesVec(employees_vec) => {
                    Ok(HttpResponse::Ok()
                        .json(employees_vec))
                }
                Results::GetEmployee(employee) => {
                    Ok(HttpResponse::Ok().json(employee))
                }
                Results::GetShiftsVec(shifts_vec) => {
                    Ok(HttpResponse::Ok().json(shifts_vec))
                }
                Results::GetShift(shift) => {
                    Ok(HttpResponse::Ok().json(shift))
                }
                Results::GetEmployeeShifts(shifts) => {
                    Ok(HttpResponse::Ok().json(shifts))
                }
                Results::Nothing => {
                    Ok(HttpResponse::Ok().finish())
                }
            }
        }
        Err(err) => {
            Ok(HttpResponse::from_error(err.into()))
        }
    }
}

fn index(
    _: &HttpRequest<AppState>,
) -> actix_web::Result<NamedFile> {
    Ok(NamedFile::open("static/index.html")?)
}

fn main() {
    let sys = actix::System::new("database-system");
    let db_url = env::get_env(ENV_DB_URL);
    let port = env::get_env(ENV_SERVER_PORT);

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

    println!(
        "CWD {:?}",
        std::fs::canonicalize("./").unwrap()
    );

    server::HttpServer::new(move || {
        App::with_state(AppState { db: addr.clone() })
            .middleware(
                actix_web::middleware::Logger::default(),
            )
            .resource("/sched", |r| r.get().f(index))
            .resource("/sched/login", |r| r.get().f(index))
            .resource("/sched/calendar", |r| {
                r.get().f(index)
            })
            .resource(API_LOGIN_REQUEST, |r| {
                r.post().with_async(login)
            })
            .resource(API_LOGOUT_REQUEST, |r| {
                r.post().with_async(logout)
            })
            .resource(API_CHANGE_PASSWORD, |r| {
                r.post().with_async(change_password)
            })
            .resource(API_GET_SETTINGS, |r| {
                r.post().with_async(get_settings)
            })
            .resource(API_DEFAULT_SETTINGS, |r| {
                r.post().with_async(default_settings)
            })
            .resource(API_ADD_SETTINGS, |r| {
                r.post().with_async(add_settings)
            })
            .resource(API_COPY_SETTINGS, |r| {
                r.post().with_async(copy_settings)
            })
            .resource(API_SET_DEFAULT_SETTINGS, |r| {
                r.post().with_async(set_default_settings)
            })
            .resource(API_UPDATE_SETTINGS, |r| {
                r.post().with_async(update_settings)
            })
            .resource(API_REMOVE_SETTINGS, |r| {
                r.post().with_async(remove_settings)
            })
            .resource(API_ADD_EMPLOYEE_SETTINGS, |r| {
                r.post().with_async(add_employee_settings)
            })
            .resource(API_UPDATE_EMPLOYEE_SETTINGS, |r| {
                r.post().with_async(update_employee_settings)
            })
            .resource(API_GET_EMPLOYEES, |r| {
                r.post().with_async(get_employees)
            })
            .resource(API_GET_EMPLOYEE, |r| {
                r.post().with_async(get_employee)
            })
            .resource(API_ADD_EMPLOYEE, |r| {
                r.post().with_async(add_employee)
            })
            .resource(API_UPDATE_EMPLOYEE, |r| {
                r.post().with_async(update_employee)
            })
            .resource(API_REMOVE_EMPLOYEE, |r| {
                r.post().with_async(remove_employee)
            })
            .resource(API_GET_SHIFTS, |r| {
                r.post().with_async(get_shifts)
            })
            .resource(API_ADD_SHIFT, |r| {
                r.post().with_async(add_shift)
            })
            .resource(API_UPDATE_SHIFT, |r| {
                r.post().with_async(update_shift)
            })
            .resource(API_REMOVE_SHIFT, |r| {
                r.post().with_async(remove_shift)
            })
            .handler(
                API_INDEX,
                actix_web::fs::StaticFiles::new("static")
                    .unwrap(),
            )
    })
    .bind(format!("localhost:{}", port))
    .unwrap()
    .start();

    let _ = sys.run();
}
