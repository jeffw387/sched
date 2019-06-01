#[macro_use]
extern crate seed;
use seed::prelude::*;
use seed::{Request, Method};
use chrono::prelude::*;
use chrono::{
    Date,
    DateTime,
    Datelike,
    Timelike,
};
use futures::prelude::*;
use futures::Future;
use serde::{
    Deserialize,
    Serialize,
};
use std::fmt::Display;

#[derive(Clone, Debug, Deserialize)]
enum HourFormat {
    H12,
    H24,
}

#[derive(Clone, Debug, Deserialize)]
enum LastNameStyle {
    Full,
    Initial,
    Hidden,
}

#[derive(Clone, Debug, Deserialize)]
struct Config {
    id: i32,
    employee_id: i32,
    config_name: String,
    hour_format: HourFormat,
    last_name_style: LastNameStyle,
    view_date: DateTime<Utc>,
    view_employees: Vec<i32>,
    show_minutes: bool,
    show_shifts: bool,
    show_vacations: bool,
    show_call_shifts: bool,
    show_disabled: bool,
}

#[derive(Clone, Debug, Deserialize)]
struct PerEmployeeConfig {
    id: i32,
    config_id: i32,
    employee_id: i32,
    color: EmployeeColor,
}

#[derive(Clone, Debug, Deserialize)]
struct CombinedConfig {
    config: Config,
    per_employee: Vec<PerEmployeeConfig>,
}

#[derive(Clone, Debug, Deserialize)]
enum EmployeeLevel {
    Read,
    Supervisor,
    Admin,
}

#[derive(Clone, Debug, Deserialize)]
enum EmployeeColor {
    Red,
    LightRed,
    Green,
    LightGreen,
    Blue,
    LightBlue,
    Yellow,
    LightYellow,
    Grey,
    LightGrey,
    Purple,
}

#[derive(Clone, Debug, Deserialize)]
struct Employee {
    id: i32,
    email: String,
    active_config: Option<i32>,
    level: EmployeeLevel,
    first: String,
    last: String,
    phone_number: Option<String>,
    default_color: EmployeeColor,
}

#[derive(Clone, Debug, Deserialize)]
enum ShiftRepeat {
    NeverRepeat,
    EveryDay,
    EveryWeek,
}

#[derive(Clone, Debug, Deserialize)]
struct Shift {
    id: i32,
    supervisor_id: i32,
    employee_id: Option<i32>,
    start: DateTime<Utc>,
    duration: std::time::Duration,
    repeat: ShiftRepeat,
    every_x: Option<i32>,
    note: Option<String>,
    on_call: bool,
}

#[derive(Clone, Debug, Deserialize)]
struct ShiftException {
    id: i32,
    shift_id: i32,
    date: DateTime<Utc>,
}

#[derive(Clone, Debug, Deserialize)]
struct Vacation {
    id: i32,
    supervisor_id: Option<i32>,
    employee_id: i32,
    approved: bool,
    start: DateTime<Utc>,
    duration: i32,
    requested: DateTime<Utc>,
}

#[derive(Clone, Default, Debug, Deserialize, Serialize)]
struct LoginInfo {
    email: String,
    password: String,
}

#[derive(Default, Clone, Debug, Deserialize)]
struct LoginModel {
    login_info: LoginInfo,
}

#[derive(Clone, Debug, Deserialize)]
enum CalendarMode {
    NoModal,
    Nav,
    ViewSelect,
    ViewEdit,
    Shift,
    Vacation,
    EmployeeEdit,
    Account,
}

#[derive(Clone, Debug, Deserialize)]
enum CalendarView {
    Day,
    DayAlt,
    Week,
    Month,
}

#[derive(Clone, Debug, Deserialize)]
struct CalendarModel {
    mode: CalendarMode,
    view_mode: CalendarView,
}

#[derive(Clone, Debug, Deserialize)]
enum Page {
    Login(LoginModel),
    Calendar(CalendarModel),
}

impl Default for Page {
    fn default() -> Self {
        Page::Login(LoginModel::default())
    }
}

#[derive(Default, Clone, Debug)]
struct Model {
    configs: Option<Vec<CombinedConfig>>,
    active_config: Option<i32>,
    current_employee: Option<Employee>,
    employees: Option<Vec<Employee>>,
    shifts: Option<Vec<Shift>>,
    shift_exceptions: Option<Vec<ShiftException>>,
    vacations: Option<Vec<Vacation>>,
    current_date_time: Option<DateTime<Utc>>,
    page: Page,
    device_class: DeviceClass,
}

#[derive(Clone, Debug, Deserialize)]
enum AccountMessage {
    OpenColorSelect,
    SetDefaultColor(EmployeeColor),
    UpdatePhone(String),
    UpdateOldPassword(String),
    UpdateNewPassword(String),
    UpdateNewPasswordAgain(String),
    ChangePassword,
    ChangePasswordResponse,
}

#[derive(Clone, Debug, Deserialize)]
enum LoginMessage {
    Login,
    LoginSuccess(Employee),
    LoginFail,
    UpdateEmail(String),
    UpdatePassword(String),
}

#[derive(Clone, Debug, Deserialize)]
enum CalendarMessage {
    SwitchView(CalendarView),
    Previous,
    Next,
    OpenModal(CalendarMode),
    CloseModal,
}

#[derive(Clone, Debug, Deserialize)]
enum EmployeeEditMessage {
    Create,
    CreateResponse(Employee),
    Filter(String),
    Select(Employee),
    UpdateEmail(String),
    UpdateFirstName(String),
    UpdateLastName(String),
    UpdatePhoneNumber(String),
    Delete,
}

#[derive(Clone, Debug, Deserialize)]
enum ShiftMessage {
    ToggleEdit,
    EmployeeFilter(String),
    UpdateNote(Option<String>),
    SelectEmployee(Employee),
    UpdateStart(f32),
    UpdateDuration(f32),
    UpdateRepeat(ShiftRepeat),
    UpdateRepeatRate(i32),
    UpdateOnCall(bool),
    UpdateException(bool),
    Delete,
}

#[derive(Clone, Debug, Deserialize)]
enum VacationMessage {
    ToggleEdit,
    UpdateSupervisor(Employee),
    UpdateDuration(i32),
    UpdateApproval(bool),
    Delete,
}

#[derive(Clone, Debug, Deserialize)]
enum AddEventMessage {
    CreateShift,
    CreateShiftResponse(Shift),
    CreateCallShift,
    CreateCallShiftResponse(Shift),
    CreateVacation,
    CreateVacationResponse(Vacation),
}

#[derive(Clone, Debug, Deserialize)]
enum ConfigSelectMessage {
    Select(i32),
    Delete(i32),
    Copy(i32),
}

#[derive(Clone, Debug, Deserialize)]
enum ConfigEditMessage {
    UpdateName(String),
    UpdateHourFormat(HourFormat),
    UpdateShowShifts(bool),
    UpdateShowCallShifts(bool),
    UpdateShowVacations(bool),
    UpdateShowDisabled(bool),
    UpdateEmployeeEnable(i32, bool),
    OpenColorSelect(Employee),
    SelectColor(Employee, EmployeeColor),
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct JsonObject<T: Clone> {
    pub contents: T,
}

impl<T: Clone> JsonObject<T> {
    pub fn new(t: T) -> Self {
        Self { contents: t }
    }
}

#[derive(Clone, Debug)]
enum Message {
    NoOp,
    Resize(f64, f64),
    SwitchPage(Page),
    HttpError(JsValue),
    Logout,
    LogoutResponse,
    // KeyDown,
    Account(AccountMessage),
    Login(LoginMessage),
    Calendar(CalendarMessage),
    EmployeeEdit(EmployeeEditMessage),
    AddEvent(AddEventMessage),
    Shift(ShiftMessage),
    ConfigEdit(ConfigEditMessage),
    ReceiveEmployees(JsonObject<Vec<Employee>>),
    ReceiveShifts(JsonObject<Vec<Shift>>),
    ReceiveShiftExceptions(JsonObject<Vec<ShiftException>>),
    ReceiveVacations(JsonObject<Vec<Vacation>>),
    ReceiveActiveConfig(JsonObject<Option<i32>>),
    ReceiveConfigs(JsonObject<Vec<CombinedConfig>>),
}

#[derive(Clone, Debug, Deserialize)]
enum DeviceClass {
    Desktop,
    HalfDesktop,
    Mobile,
}

impl Default for DeviceClass {
    fn default() -> Self {
        DeviceClass::Mobile
    }
}

impl Display for DeviceClass {
    fn fmt(
        &self,
        f: &mut std::fmt::Formatter,
    ) -> std::fmt::Result {
        write!(f, "Device class: ")?;
        match self {
            DeviceClass::Desktop => write!(f, "Desktop"),
            DeviceClass::HalfDesktop => {
                write!(f, "Half desktop")
            }
            DeviceClass::Mobile => write!(f, "Mobile"),
        }
    }
}

fn view_login_page(
    model: &Model,
    login_model: &LoginModel,
) -> El<Message> {
    let width_style = match model.device_class {
        DeviceClass::Mobile => {
            style! { "width" => "95%" }
        }
        _ => style! { "width" => "80%" },
    };
    div![
        width_style.clone(),
        style! {
            "margin" => "auto";
            "background-color" => "#AAAAAA";
        },
        h1![
            style! {"text-align" => "center"},
            "Log into scheduler"
        ],
        fieldset![
            style! {
                "padding" => "2%";
                "margin-top" => "1%";
            },
            input![
                style! {
                    "margin" => "inherit";
                },
                attrs! {
                    "type" => "text";
                    "value" => login_model.login_info.email;
                    "placeholder" => "Email"
                },
                input_ev(Ev::Input, move |email| {
                    Message::Login(
                        LoginMessage::UpdateEmail(email),
                    )
                })
            ],
            input![
                style! {
                    "margin" => "inherit";
                },
                attrs! {
                    "type" => "password";
                    "value" => login_model.login_info.password;
                    "placeholder" => "Password"
                },
                input_ev(Ev::Input, move |password| {
                    Message::Login(
                        LoginMessage::UpdatePassword(
                            password,
                        ),
                    )
                })
            ],
            input![
                style! {
                    "margin" => "inherit auto";
                },
                attrs! {
                    "type" => "submit";
                    "class" => "submit";
                    "value" => "Submit";
                },
                input_ev(Ev::Click, move |_| {
                    Message::Login(LoginMessage::Login)
                })
            ]
        ]
    ]
}

fn nav_item<F: FnOnce() -> Message>(
    text: &str,
    f: F,
) -> El<Message> {
    input![
        attrs! {
            "class" => "button";
            "value" => text;
        },
        simple_ev(Ev::Click, f())
    ]
}

fn view_calendar_modal(
    model: &Model,
    calendar_model: &CalendarModel,
) -> El<Message> {
    div![
        nav![
            input![
                attrs! {
                    "type" => "checkbox";
                    "class" => "show";
                    "id" => "navtoggle";
                    "checked" => match calendar_model.mode {
                        CalendarMode::Nav => true,
                        _ => false,
                    };
                },
                simple_ev(
                    Ev::Click,
                    Message::Calendar(
                        CalendarMessage::OpenModal(
                            CalendarMode::Nav
                        )
                    )
                )
            ],
            label![
                attrs! {
                    "for" => "navtoggle";
                    "class" => "burger pseudo button";
                },
                "Menu"
            ],
            div![
                attrs! {
                    "class" => "menu";
                },
                nav_item("Account", move || {
                    Message::Calendar(
                        CalendarMessage::OpenModal(
                            CalendarMode::Account,
                        ),
                    )
                }),
                nav_item("Views", move || {
                    Message::Calendar(
                        CalendarMessage::OpenModal(
                            CalendarMode::ViewSelect,
                        ),
                    )
                }),
                nav_item("Configuration", move || {
                    Message::Calendar(
                        CalendarMessage::OpenModal(
                            CalendarMode::ViewEdit,
                        ),
                    )
                }),
                nav_item("Log out", move || {
                    Message::Logout
                }),
            ]
        ],
        div![
            attrs!{
                "class" => "modal";
            },
            input![
                attrs!{
                    "id" => "account_modal";
                    "type" => "checkbox";
                    "checked" => match calendar_model.mode {
                        CalendarMode::Account => true,
                        _ => false
                    }
                }
            ],
            label![
                attrs!{
                    "for" => "account_modal";
                    "class" => "overlay";
                },
                simple_ev(Ev::Click, Message::Calendar(CalendarMessage::CloseModal))
            ],
            article![
                section![
                    attrs!{
                        "class" => "content"
                    },
                    "Account Modal"
                ]
            ]
        ]
    ]
}

fn view_calendar_day(
    model: &Model,
    calendar_model: &CalendarModel,
) -> El<Message> {
    div!["Day View"]
}

fn view_calendar_day_alt(
    model: &Model,
    calendar_model: &CalendarModel,
) -> El<Message> {
    unimplemented!()
}

fn view_calendar_week(
    model: &Model,
    calendar_model: &CalendarModel,
) -> El<Message> {
    unimplemented!()
}

fn view_calendar_month(
    model: &Model,
    calendar_model: &CalendarModel,
) -> El<Message> {
    unimplemented!()
}

fn view_calendar_page(
    model: &Model,
    calendar_model: &CalendarModel,
) -> El<Message> {
    div![
        view_calendar_modal(model, calendar_model),
        match calendar_model.view_mode {
            CalendarView::Day => {
                view_calendar_day(model, calendar_model)
            }
            CalendarView::DayAlt => {
                view_calendar_day_alt(model, calendar_model)
            }
            CalendarView::Week => {
                view_calendar_week(model, calendar_model)
            }
            CalendarView::Month => {
                view_calendar_month(model, calendar_model)
            }
        }
    ]
}

fn view(model: &Model) -> El<Message> {
    log!(model);
    match &model.page {
        Page::Login(page) => view_login_page(model, page),
        Page::Calendar(page) => {
            view_calendar_page(model, page)
        }
    }
}

fn classify_device(w: &f64) -> DeviceClass {
    match *w as i32 {
        0...600 => DeviceClass::Mobile,
        601...1000 => DeviceClass::HalfDesktop,
        _ => DeviceClass::Desktop,
    }
}

#[derive(Deserialize, Debug, Clone)]
struct LoginResult {
    employee: Option<Employee>,
}

fn handle_login_result(r: LoginResult) -> Message {
    match r.employee {
        Some(employee) => {
            Message::Login(LoginMessage::LoginSuccess(
                employee,
            ))
        }
        None => Message::Login(LoginMessage::LoginFail),
    }
}

fn update(
    msg: Message,
    model: &mut Model,
    orders: &mut Orders<Message>,
) {
    log!(msg);
    match (&model.page, &model.current_employee) {
        (Page::Calendar(_), None) => {
            let login_page =
                Page::Login(LoginModel::default());
            orders
                .send_msg(Message::SwitchPage(login_page));
        }
        _ => (),
    };
    match (&mut model.page, &msg) {
        (_, Message::Resize(w, _)) => {
            model.device_class = classify_device(w);
        }
        (_, Message::HttpError(js_value)) => {
            log!(js_value);
            model.current_employee = None;
        }
        (
            Page::Login(page),
            Message::Login(login_message),
        ) => {
            match login_message {
                LoginMessage::UpdateEmail(email) => {
                    page.login_info.email = email.clone();
                }
                LoginMessage::UpdatePassword(password) => {
                    page.login_info.password =
                        password.clone();
                }
                LoginMessage::Login => {
                    let req =
                        Request::new("/sched/login")
                            .method(Method::Post)
                            .header(
                                "Content-Type",
                                "text/json;charset=UTF-8",
                            )
                            .body_json(&page.login_info)
                            .fetch_json()
                            .map(handle_login_result)
                            .map_err(|_| {
                                Message::Login(
                                    LoginMessage::LoginFail,
                                )
                            });
                    orders.skip().perform_cmd(req);
                }
                LoginMessage::LoginSuccess(employee) => {
                    model.current_employee =
                        Some(employee.clone());
                    let calendar_model = CalendarModel {
                        mode: CalendarMode::NoModal,
                        view_mode: CalendarView::Day,
                    };
                    orders.send_msg(Message::SwitchPage(
                        Page::Calendar(calendar_model),
                    ));
                }
                LoginMessage::LoginFail => (),
            }
        }
        (
            Page::Calendar(page),
            Message::Calendar(CalendarMessage::OpenModal(
                mode,
            )),
        ) => {
            page.mode = mode.clone();
        }
        (
            Page::Calendar(page),
            Message::Calendar(CalendarMessage::CloseModal)
        ) => {
            page.mode = CalendarMode::NoModal;
        }
        (_, Message::SwitchPage(page)) => {
            model.page = page.clone();
            match model.page {
                Page::Calendar(_) => {
                    let req_emps = Request::new("/sched/get_employees")
                        .method(Method::Post)
                        .fetch_json()
                        .map(Message::ReceiveEmployees)
                        .map_err(Message::HttpError);
                    orders.perform_cmd(req_emps);
                    let req_configs = Request::new("/sched/get_configs")
                        .method(Method::Post)
                        .fetch_json()
                        .map(Message::ReceiveConfigs)
                        .map_err(Message::HttpError);
                    orders.perform_cmd(req_configs);
                    let req_active_config = Request::new("/sched/get_active_config")
                        .method(Method::Post)
                        .fetch_json()
                        .map(Message::ReceiveActiveConfig)
                        .map_err(Message::HttpError);
                    orders.perform_cmd(req_active_config);
                    let req_shifts = Request::new("/sched/get_shifts")
                        .method(Method::Post)
                        .fetch_json()
                        .map(Message::ReceiveShifts)
                        .map_err(Message::HttpError);
                    orders.perform_cmd(req_shifts);
                    let req_shift_exceptions = Request::new("/sched/get_shift_exceptions")
                        .method(Method::Post)
                        .fetch_json()
                        .map(Message::ReceiveShiftExceptions)
                        .map_err(Message::HttpError);
                    orders.perform_cmd(req_shift_exceptions);
                    let req_vacations = Request::new("/sched/get_vacations")
                        .method(Method::Post)
                        .fetch_json()
                        .map(Message::ReceiveVacations)
                        .map_err(Message::HttpError);
                    orders.perform_cmd(req_vacations);
                }
                _ => ()
            }
        }
        _ => (),
    }
}

fn window_width() -> f64 {
    seed::window()
        .inner_width()
        .ok()
        .unwrap()
        .as_f64()
        .unwrap()
}

fn window_height() -> f64 {
    seed::window()
        .inner_height()
        .ok()
        .unwrap()
        .as_f64()
        .unwrap()
}

fn window_events(
    _: &Model,
) -> Vec<seed::dom_types::Listener<Message>> {
    vec![simple_ev(
        seed::dom_types::Ev::Resize,
        Message::Resize(window_width(), window_height()),
    )]
}

#[wasm_bindgen]
pub fn render() {
    let init_model = Model {
        configs: None,
        active_config: None,
        current_employee: None,
        employees: None,
        shifts: None,
        shift_exceptions: None,
        vacations: None,
        current_date_time: None,
        page: Page::default(),
        device_class: classify_device(&window_width()),
    };
    seed::App::build(init_model, update, view)
        .window_events(window_events)
        .finish()
        .run();
}
