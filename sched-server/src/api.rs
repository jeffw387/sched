use crate::db::{
    self,
    PgPool,
    JsonObject,
};
use crate::message::{
    ChangePasswordInfo,
    LoginInfo,
};
use crate::config::{
    NewPerEmployeeConfig,
    NewConfig,
    PerEmployeeConfig,
    Config,
    CombinedConfig,
    EmployeeColor,
};
use crate::employee::{
    ClientSideEmployee
};
use crate::shift::{
    NewShift,
    Shift,
    NewShiftException,
    ShiftException,
    NewVacation,
    Vacation
};
use actix_http::cookie;
use actix_http::httpmessage::HttpMessage;
use actix_web::web::{
    self,
    Data,
    HttpRequest,
    HttpResponse,
    Json,
};
use futures::Future;
use serde::Serialize;
const SESSION_COOKIE_KEY: &str = "session";

fn get_token(request: &HttpRequest) -> String {
    match request.cookie(SESSION_COOKIE_KEY) {
        Some(token) => String::from(token.value()),
        None => String::new(),
    }
}

pub fn login(
    pool: Data<PgPool>,
    login_info: Json<LoginInfo>,
) -> impl Future<Item = HttpResponse, Error = actix_web::Error>
{
    web::block(move || {
        db::login(pool, login_info.into_inner())
    })
    .then(|res| {
        match res {
            Ok(token) => {
                let ck = cookie::CookieBuilder::new(
                    SESSION_COOKIE_KEY,
                    token,
                )
                .same_site(cookie::SameSite::Strict)
                .http_only(true)
                .finish();
                Ok(HttpResponse::Ok().cookie(ck).finish())
            }
            Err(_) => {
                Ok(HttpResponse::InternalServerError()
                    .finish())
            }
        }
    })
}

pub trait ApiFuture =
    Future<Item = HttpResponse, Error = actix_web::Error>;

fn no_return<T, E>(res: Result<T, E>) -> HttpResponse {
    match res {
        Ok(_) => HttpResponse::Ok().finish(),
        Err(_) => HttpResponse::Unauthorized().finish(),
    }
}

fn return_json<T: Serialize, E>(
    res: Result<T, E>,
) -> HttpResponse {
    match res {
        Ok(t) => HttpResponse::Ok().json(t),
        Err(_) => {
            HttpResponse::InternalServerError().finish()
        }
    }
}

pub fn check_token(
    req: HttpRequest,
    pool: Data<PgPool>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || db::check_token(&token, pool))
        .then(no_return)
}

pub fn change_password(
    req: HttpRequest,
    pool: Data<PgPool>,
    change_info: Json<ChangePasswordInfo>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::change_password(
            pool,
            token,
            change_info.into_inner(),
        )
    })
    .then(no_return)
}

pub fn default_config(
    req: HttpRequest,
    pool: Data<PgPool>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || db::default_config(pool, token))
        .then(return_json)
}

pub fn set_default_config(
    req: HttpRequest,
    pool: Data<PgPool>,
    config: Json<Config>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::set_default_config(
            pool,
            token,
            (*config).clone(),
        )
    })
    .then(return_json)
}

pub fn logout(
    req: HttpRequest,
    pool: Data<PgPool>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::logout(pool, token)
    })
    .then(no_return)
}

pub fn get_config(
    req: HttpRequest,
    pool: Data<PgPool>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::get_config(pool, token)
    })
    .then(return_json)
}

pub fn add_config(
    req: HttpRequest,
    pool: Data<PgPool>,
    new_config: Json<NewConfig>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::add_config(pool, token, (*new_config).clone())
    })
    .then(return_json)
}

pub fn update_config(
    req: HttpRequest,
    pool: Data<PgPool>,
    config: Json<Config>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::update_config(pool, token, (*config).clone())
    })
    .then(return_json)
}

pub fn copy_config(
    req: HttpRequest,
    pool: Data<PgPool>,
    combined_config: Json<CombinedConfig>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::copy_config(pool, token, (*combined_config).clone())
    })
    .then(no_return)
}

pub fn remove_config(
    req: HttpRequest,
    pool: Data<PgPool>,
    config: Json<Config>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::remove_config(pool, token, (*config).clone())
    })
    .then(no_return)
}

pub fn add_employee_config(
    req: HttpRequest,
    pool: Data<PgPool>,
    new_config: Json<NewPerEmployeeConfig>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::add_employee_config(pool, token, (*new_config).clone())
    })
    .then(no_return)
}

pub fn update_employee_config(
    req: HttpRequest,
    pool: Data<PgPool>,
    config: Json<PerEmployeeConfig>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::update_employee_config(pool, token, (*config).clone())
    })
    .then(no_return)
}

pub fn get_employees(
    req: HttpRequest,
    pool: Data<PgPool>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::get_employees(pool, token)
    })
    .then(return_json)
}

pub fn get_current_employee(
    req: HttpRequest,
    pool: Data<PgPool>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::get_current_employee(pool, token)
    })
    .then(return_json)
}

pub fn add_employee(
    req: HttpRequest,
    pool: Data<PgPool>,
    new_employee: Json<ClientSideEmployee>
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::add_employee(pool, token, (*new_employee).clone())
    })
    .then(return_json)
}

pub fn update_employee(
    req: HttpRequest,
    pool: Data<PgPool>,
    employee: Json<ClientSideEmployee>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::update_employee(pool, token, (*employee).clone())
    })
    .then(no_return)
}

pub fn update_employee_color(
    req: HttpRequest,
    pool: Data<PgPool>,
    color: Json<JsonObject<EmployeeColor>>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::update_employee_color(pool, token, (*color).clone().contents)
    })
    .then(no_return)
}

pub fn update_employee_phone_number(
    req: HttpRequest,
    pool: Data<PgPool>,
    phone_number: Json<JsonObject<String>>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::update_employee_phone_number(pool, token, (*phone_number).clone().contents)
    })
    .then(no_return)
}

pub fn remove_employee(
    req: HttpRequest,
    pool: Data<PgPool>,
    employee: Json<ClientSideEmployee>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::remove_employee(pool, token, (*employee).clone())
    })
    .then(no_return)
}

pub fn get_shifts(
    req: HttpRequest,
    pool: Data<PgPool>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::get_shifts(pool, token)
    })
    .then(return_json)
}

pub fn add_shift(
    req: HttpRequest,
    pool: Data<PgPool>,
    shift: Json<NewShift>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::add_shift(pool, token, (*shift).clone())
    })
    .then(return_json)
}

pub fn update_shift(
    req: HttpRequest,
    pool: Data<PgPool>,
    shift: Json<Shift>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::update_shift(pool, token, (*shift).clone())
    })
    .then(return_json)
}

pub fn remove_shift(
    req: HttpRequest,
    pool: Data<PgPool>,
    shift: Json<Shift>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::remove_shift(pool, token, (*shift).clone())
    })
    .then(no_return)
}

pub fn get_shift_exceptions(
    req: HttpRequest,
    pool: Data<PgPool>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::get_shift_exceptions(pool, token)
    })
    .then(return_json)
}

pub fn add_shift_exception(
    req: HttpRequest,
    pool: Data<PgPool>,
    exception: Json<NewShiftException>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::add_shift_exception(pool, token, (*exception).clone())
    })
    .then(return_json)
}

pub fn remove_shift_exception(
    req: HttpRequest,
    pool: Data<PgPool>,
    exception: Json<ShiftException>
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::remove_shift_exception(pool, token, (*exception).clone())
    })
    .then(no_return)
}

pub fn get_vacations(
    req: HttpRequest,
    pool: Data<PgPool>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::get_vacations(pool, token)
    })
    .then(return_json)
}

pub fn add_vacation(
    req: HttpRequest,
    pool: Data<PgPool>,
    vacation: Json<NewVacation>
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::add_vacation(pool, token, (*vacation).clone())
    })
    .then(return_json)
}

pub fn update_vacation(
    req: HttpRequest,
    pool: Data<PgPool>,
    vacation: Json<Vacation>
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::update_vacation(pool, token, (*vacation).clone())
    })
    .then(return_json)
}

pub fn remove_vacation(
    req: HttpRequest,
    pool: Data<PgPool>,
    vacation: Json<Vacation>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::remove_vacation(pool, token, (*vacation).clone())
    })
    .then(no_return)
}

pub fn update_vacation_approval(
    req: HttpRequest,
    pool: Data<PgPool>,
    vacation: Json<Vacation>,
) -> impl ApiFuture {
    let token = get_token(&req);
    web::block(move || {
        db::update_vacation_approval(pool, token, (*vacation).clone())
    })
    .then(return_json)
}