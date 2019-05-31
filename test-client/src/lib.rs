#[macro_use]
extern crate seed;
use chrono::prelude::*;
use chrono::{
    Date,
    DateTime,
    Datelike,
    Timelike,
};
use futures::prelude::*;
use futures::Future;
use seed::prelude::*;
use std::fmt::Display;

enum HourFormat {
    H12,
    H24,
}
enum LastNameStyle {
    Full,
    Initial,
    Hidden,
}
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
struct PerEmployeeConfig {
    id: i32,
    config_id: i32,
    employee_id: i32,
    color: EmployeeColor,
}
struct CombinedConfig {
    config: Config,
    per_employee: Vec<PerEmployeeConfig>,
}
enum EmployeeLevel {
    Read,
    Supervisor,
    Admin,
}
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
enum ShiftRepeat {
    NeverRepeat,
    EveryDay,
    EveryWeek,
}
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
struct ShiftException {
    id: i32,
    shift_id: i32,
    date: Date<Utc>,
}
struct Vacation {
    id: i32,
    supervisor_id: Option<i32>,
    employee_id: i32,
    approved: bool,
    start: Date<Utc>,
    duration: i32,
    requested: Date<Utc>,
}

#[derive(Default)]
struct LoginInfo {
    email: String,
    password: String,
}

#[derive(Default)]
struct LoginModel {
    login_info: LoginInfo,
}

enum CalendarMode {
    NoModal,
    ViewSelect,
    ViewEdit,
    Shift,
    Vacation,
    EmployeeEdit,
    Account,
}

enum CalendarView {
    Day,
    DayAlt,
    Week,
    Month,
}

struct CalendarModel {
    mode: CalendarMode,
    view_mode: CalendarView,
}

enum Page {
    Login(LoginModel),
    Calendar(CalendarModel),
}

impl Default for Page {
    fn default() -> Self {
        Page::Login(LoginModel::default())
    }
}

#[derive(Default)]
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

enum LoginMessage {
    Login,
    LoginSuccess,
    LoginFail(JsValue),
    UpdateEmail(String),
    UpdatePassword(String),
}

enum CalendarMessage {
    SwitchView(CalendarView),
    Previous,
    Next,
    OpenModal(CalendarMode),
    CloseModal,
}

enum EmployeeEditMessage {
    CreateEmployee,
    CreateEmployeeResponse,
    EmployeeFilter(String),
    SelectEmployee(Employee),
    UpdateEmail(String),
    UpdateFirstName(String),
    UpdateLastName(String),
    UpdatePhoneNumber(String),
    RemoveEmployee,
}

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

enum VacationMessage {
    ToggleEdit,
    UpdateSupervisor(Employee),
    UpdateDuration(i32),
    UpdateApproval(bool),
    Delete,
}

enum AddEventMessage {
    CreateShift,
    CreateShiftResponse,
    CreateCallShift,
    CreateCallShiftResponse,
    CreateVacation,
    CreateVacationResponse,
}

enum ConfigSelectMessage {
    Select(i32),
    Delete(i32),
    Copy(i32),
}

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

enum Message {
    NoOp,
    Resize(f64, f64),
    SwitchPage(Page),
    IgnoreHttpReply,
    CheckTokenResponse,
    Logout,
    LogoutResponse,
    KeyDown,
    Account(AccountMessage),
    Login(LoginMessage),
    Calendar(CalendarMessage),
    EmployeeEdit(EmployeeEditMessage),
    AddEvent(AddEventMessage),
    Shift(ShiftMessage),
    ConfigEdit(ConfigEditMessage),
    ReceiveCurrentEmployee,
    ReceiveEmployees,
    ReceiveShifts,
    ReceiveShiftExceptions,
    ReceiveVacations,
    ReceiveActiveConfig,
    ReceiveConfigs,
}

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

fn view(model: &Model) -> El<Message> {
    match &model.page {
        Page::Login(page) => {
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
                            "value" => page.login_info.email;
                            "placeholder" => "Email"
                        },
                        input_ev(Ev::Input, move |email| {
                            Message::Login(
                                LoginMessage::UpdateEmail(
                                    email,
                                ),
                            )
                        })
                    ],
                    input![
                        style! {
                            "margin" => "inherit";
                        },
                        attrs! {
                            "type" => "password";
                            "value" => page.login_info.password;
                            "placeholder" => "Password"
                        },
                        input_ev(
                            Ev::Input,
                            move |password| {
                                Message::Login(
                            LoginMessage::UpdatePassword(
                                password,
                            ),
                        )
                            }
                        )
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
                            Message::Login(
                                LoginMessage::Login,
                            )
                        })
                    ]
                ]
            ]
        }
        Page::Calendar(page) => div![],
    }
}

fn classify_device(w: &f64) -> DeviceClass {
    match *w as i32 {
        0...600 => DeviceClass::Mobile,
        601...1000 => DeviceClass::HalfDesktop,
        _ => DeviceClass::Desktop,
    }
}

fn update(
    msg: Message,
    model: &mut Model,
    orders: &mut Orders<Message>,
) {
    match (&mut model.page, &msg) {
        (_, Message::Resize(w, _)) => {
            model.device_class = classify_device(w);
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
                        seed::Request::new("/sched/login")
                            .method(seed::Method::Post)
                            .fetch()
                            .map(|_| {
                                Message::Login(
                            LoginMessage::LoginSuccess,
                        )
                            })
                            .map_err(|e| {
                                Message::Login(
                                    LoginMessage::LoginFail(
                                        e,
                                    ),
                                )
                            });
                    orders.skip().perform_cmd(req);
                }
                _ => (),
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

fn resize_handler() -> Message {
    Message::Resize(window_width(), window_height())
}

fn window_events(
    _: &Model,
) -> Vec<seed::dom_types::Listener<Message>> {
    vec![raw_ev(seed::dom_types::Ev::Resize, move |_| {
        resize_handler()
    })]
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
