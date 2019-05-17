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
        .map(log_json)
        .map_err(|e| log_err(e, "login json"))
        .from_err()
        .and_then(move |login_info: LoginInfo| {
            db.send(Messages::Login(login_info))
                .map_err(|e| log_err(e, "login"))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn logout((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    state
        .db
        .clone()
        .send(Messages::Logout(token))
        .map_err(|e| log_err(e, ""))
        .from_err()
        .and_then(handle_results)
        .responder()
}

fn change_password(
    (req, state): DbRequest,
) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map(log_json)
        .map_err(|e| log_err(e, "change_password json"))
        .from_err()
        .and_then(move |change_password_info| {
            state
                .db
                .clone()
                .send(Messages::ChangePassword(
                    token,
                    change_password_info,
                ))
                .map_err(|e| log_err(e, "change_password"))
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
        .map_err(|e| log_err(e, "get_settings"))
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
        .map_err(|e| log_err(e, "default_settings"))
        .from_err()
        .and_then(handle_results)
        .responder()
}

fn add_settings((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map(log_json)
        .map_err(|e| log_err(e, ""))
        .from_err()
        .and_then(move |new_settings| {
            state
                .db
                .clone()
                .send(Messages::AddSettings(
                    token,
                    new_settings,
                ))
                .map_err(|e| log_err(e, ""))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn copy_settings((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map(log_json)
        .map_err(|e| log_err(e, "copy_settings"))
        .from_err()
        .and_then(move |original| {
            state
                .db
                .clone()
                .send(Messages::CopySettings(
                    token, original,
                ))
                .map_err(|e| log_err(e, ""))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn set_default_settings(
    (req, state): DbRequest,
) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map(log_json)
        .map_err(|e| log_err(e, "set_default_settings json"))
        .from_err()
        .and_then(move |settings| {
            state
                .db
                .clone()
                .send(Messages::SetDefaultSettings(
                    token, settings,
                ))
                .map_err(|e| log_err(e, "set_default_settings"))
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
        .map(log_json)
        .map_err(|e| log_err(e, "update_settings"))
        .from_err()
        .and_then(move |updated_settings| {
            state
                .db
                .clone()
                .send(Messages::UpdateSettings(
                    token,
                    updated_settings,
                ))
                .map_err(|e| log_err(e, ""))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn remove_settings(
    (req, state): DbRequest,
) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map(log_json)
        .map_err(|e| log_err(e, ""))
        .from_err()
        .and_then(move |settings| {
            state
                .db
                .clone()
                .send(Messages::RemoveSettings(
                    token, settings,
                ))
                .map_err(|e| log_err(e, ""))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn add_employee_settings(
    (req, state): DbRequest,
) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map(log_json)
        .map_err(|e| log_err(e, ""))
        .from_err()
        .and_then(move |new_settings| {
            state
                .db
                .clone()
                .send(Messages::AddEmployeeSettings(
                    token,
                    new_settings,
                ))
                .map_err(|e| log_err(e, ""))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn update_employee_settings(
    (req, state): DbRequest,
) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map(log_json)
        .map_err(|e| log_err(e, ""))
        .from_err()
        .and_then(move |settings| {
            state
                .db
                .clone()
                .send(Messages::UpdateEmployeeSettings(
                    token, settings,
                ))
                .map_err(|e| log_err(e, ""))
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
        .map_err(|e| log_err(e, "get_employees"))
        .from_err()
        .and_then(handle_results)
        .responder()
}

fn get_current_employee(
    (req, state): DbRequest,
) -> Box<DbFuture> {
    let token = get_token(&req);
    state
        .db
        .clone()
        .send(Messages::GetCurrentEmployee(token))
        .map_err(|e| log_err(e, "get_current_employee"))
        .from_err()
        .and_then(handle_results)
        .responder()
}

fn add_employee((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map(log_json)
        .map_err(|e| log_err(e, ""))
        .from_err()
        .and_then(move |new_employee| {
            state
                .db
                .clone()
                .send(Messages::AddEmployee(
                    token,
                    new_employee,
                ))
                .map_err(|e| log_err(e, ""))
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
        .map(log_json)
        .map_err(|e| log_err(e, ""))
        .from_err()
        .and_then(move |updated_employee| {
            state
                .db
                .clone()
                .send(Messages::UpdateEmployee(
                    token,
                    updated_employee,
                ))
                .map_err(|e| log_err(e, ""))
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
        .map(log_json)
        .map_err(|e| log_err(e, ""))
        .from_err()
        .and_then(move |employee| {
            state
                .db
                .clone()
                .send(Messages::RemoveEmployee(
                    token, employee,
                ))
                .map_err(|e| log_err(e, ""))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn get_shifts((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    state
        .db
        .send(Messages::GetShifts(token))
        .map_err(|e| log_err(e, "get_shifts"))
        .from_err()
        .and_then(handle_results)
        .responder()
}

fn get_vacations((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    state
        .db
        .send(Messages::GetVacations(token))
        .map_err(|e| log_err(e, "get_vacations"))
        .from_err()
        .and_then(handle_results)
        .responder()
}

fn add_vacation((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map(log_json)
        .map_err(|e| log_err(e, ""))
        .from_err()
        .and_then(move |new_vacation| {
            state.db.clone()
                .send(Messages::AddVacation(token, new_vacation))
                .map_err(|e| log_err(e, ""))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn update_vacation((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map(log_json)
        .map_err(|e| log_err(e, ""))
        .from_err()
        .and_then(move |updated| {
            state.db.clone()
                .send(Messages::UpdateVacation(token, updated))
                .map_err(|e| log_err(e, ""))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn update_vacation_approval((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map(log_json)
        .map_err(|e| log_err(e, "update_vacation_approval json"))
        .from_err()
        .and_then(move |updated| {
            state.db.clone()
                .send(Messages::UpdateVacationApproval(token, updated))
                .map_err(|e| log_err(e, "update_vacation_approval"))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn remove_vacation((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map(log_json)
        .map_err(|e| log_err(e, ""))
        .from_err()
        .and_then(move |to_remove| {
            state.db.clone()
                .send(Messages::RemoveVacation(token, to_remove))
                .map_err(|e| log_err(e, ""))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn log_err<T: std::fmt::Debug>(t: T, m: &str) -> T {
    eprintln!("Error {}: {:?}", m, t);
    t
}

fn log_json<T: std::fmt::Debug>(t: T) -> T {
    println!("Json: {:#?}", t);
    t
}

fn add_shift((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map(log_json)
        .map_err(|e| log_err(e, ""))
        .from_err()
        .and_then(move |new_shift| {
            state
                .db
                .clone()
                .send(Messages::AddShift(token, new_shift))
                .map_err(|e| log_err(e, ""))
                .from_err()
                .and_then(handle_results)
                .responder()
        })
        .responder()
}

fn update_shift((req, state): DbRequest) -> Box<DbFuture> {
    let token = get_token(&req);
    req.json()
        .map(log_json)
        .map_err(|e| log_err(e, ""))
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
    let token = get_token(&req);
    req.json()
        .map(log_json)
        .map_err(|e| log_err(e, ""))
        .from_err()
        .and_then(move |shift| {
            state
                .db
                .clone()
                .send(Messages::RemoveShift(token, shift))
                .map_err(|e| log_err(e, ""))
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
                Results::GetVacations(vacations) => {
                    Ok(HttpResponse::Ok().json(vacations))
                }
                Results::GetVacation(vacation) => {
                    Ok(HttpResponse::Ok().json(vacation))
                }
                Results::Nothing => {
                    Ok(HttpResponse::Ok().finish())
                }
            }
        }
        Err(err) => {
            println!("Error: {:?}", err);
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
    let socket_url = env::get_env(ENV_SERVER_SOCKET);

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
            .resource("/", |r| r.get().f(index))
            .resource("/sched", |r| r.get().f(index))
            .resource("/sched/", |r| r.get().f(index))
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
                r.post()
                    .with_async(update_employee_settings)
            })
            .resource(API_GET_EMPLOYEES, |r| {
                r.post().with_async(get_employees)
            })
            .resource(API_GET_CURRENT_EMPLOYEE, |r| {
                r.post().with_async(get_current_employee)
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
            .resource(API_GET_VACATIONS, |r| {
                r.post().with_async(get_vacations)
            })
            .resource(API_ADD_VACATION, |r| {
                r.post().with_async(add_vacation)
            })
            .resource(API_UPDATE_VACATION, |r| {
                r.post().with_async(update_vacation)
            })
            .resource(API_UPDATE_VACATION_APPROVAL, |r| {
                r.post().with_async(update_vacation_approval)
            })
            .resource(API_REMOVE_VACATION, |r| {
                r.post().with_async(remove_vacation)
            })
            .handler(
                API_INDEX,
                actix_web::fs::StaticFiles::new("static")
                    .unwrap(),
            )
    })
    .bind(format!("{}", socket_url))
    .unwrap()
    .start();

    let _ = sys.run();
}
