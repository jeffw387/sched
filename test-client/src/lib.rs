#![recursion_limit = "256"]

#[macro_use]
use chrono::prelude::*;
use chrono::{
    Date,
    DateTime,
    Datelike,
    Timelike,
};
use dodrio::builder::text;
use dodrio::bumpalo::{
    self,
    Bump,
};
use dodrio::{
    Render,
    VdomWeak,
};
use futures::prelude::*;
use futures::{future, Future};
use log::*;
use serde::{
    Deserialize,
    Serialize,
};
use std::fmt::Display;
use typed_html::dodrio;
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;
use wasm_bindgen_futures::{future_to_promise, JsFuture};
use web_sys::{
    Event,
    HtmlInputElement,
    InputEvent,
    Request,
    RequestInit,
    RequestMode,
    Response,
};
use js_sys::Promise;


#[derive(Clone, Debug, Deserialize, Serialize)]
enum HourFormat {
    H12,
    H24,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
enum LastNameStyle {
    Full,
    Initial,
    Hidden,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
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

#[derive(Clone, Debug, Deserialize, Serialize)]
struct PerEmployeeConfig {
    id: i32,
    config_id: i32,
    employee_id: i32,
    color: EmployeeColor,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
struct CombinedConfig {
    config: Config,
    per_employee: Vec<PerEmployeeConfig>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
enum EmployeeLevel {
    Read,
    Supervisor,
    Admin,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
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

#[derive(Clone, Debug, Deserialize, Serialize)]
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

#[derive(Clone, Debug, Deserialize, Serialize)]
enum ShiftRepeat {
    NeverRepeat,
    EveryDay,
    EveryWeek,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
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

#[derive(Clone, Debug, Deserialize, Serialize)]
struct ShiftException {
    id: i32,
    shift_id: i32,
    date: DateTime<Utc>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
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

#[derive(Default, Clone, Debug, Deserialize, Serialize)]
struct LoginModel {
    login_info: LoginInfo,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
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

#[derive(Clone, Debug, Deserialize, Serialize)]
enum CalendarView {
    Day,
    DayAlt,
    Week,
    Month,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
struct CalendarModel {
    mode: CalendarMode,
    view_mode: CalendarView,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
enum Page {
    Login(LoginModel),
    Calendar(CalendarModel),
}

impl Default for Page {
    fn default() -> Self {
        Page::Login(LoginModel::default())
    }
}

#[derive(Clone, Debug)]
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

#[derive(Clone, Debug, Deserialize, Serialize)]
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

#[derive(Clone, Debug, Deserialize, Serialize)]
enum LoginMessage {
    Login,
    LoginSuccess(Employee),
    LoginFail,
    UpdateEmail(String),
    UpdatePassword(String),
}

#[derive(Clone, Debug, Deserialize, Serialize)]
enum CalendarMessage {
    SwitchView(CalendarView),
    Previous,
    Next,
    OpenModal(CalendarMode),
    CloseModal,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
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

#[derive(Clone, Debug, Deserialize, Serialize)]
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

#[derive(Clone, Debug, Deserialize, Serialize)]
enum VacationMessage {
    ToggleEdit,
    UpdateSupervisor(Employee),
    UpdateDuration(i32),
    UpdateApproval(bool),
    Delete,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
enum AddEventMessage {
    CreateShift,
    CreateShiftResponse(Shift),
    CreateCallShift,
    CreateCallShiftResponse(Shift),
    CreateVacation,
    CreateVacationResponse(Vacation),
}

#[derive(Clone, Debug, Deserialize, Serialize)]
enum ConfigSelectMessage {
    Select(i32),
    Delete(i32),
    Copy(i32),
}

#[derive(Clone, Debug, Deserialize, Serialize)]
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

#[derive(Clone, Debug, Deserialize, Serialize)]
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

fn login_update_email(
    root: &mut dyn dodrio::RootRender,
    vdom: VdomWeak,
    event: Event,
) {
    let model: &mut Model = root.unwrap_mut::<Model>();
    let input_element = event
        .target()
        .unwrap_throw()
        .unchecked_into::<HtmlInputElement>(
    );
    match &mut model.page {
        Page::Login(page) => {
            page.login_info.email = input_element.value();
        }
        _ => (),
    };
    vdom.schedule_render();
}

fn login_update_password(
    root: &mut dyn dodrio::RootRender,
    vdom: VdomWeak,
    event: Event,
) {
    let model: &mut Model = root.unwrap_mut::<Model>();
    let input_element = event
        .target()
        .unwrap_throw()
        .unchecked_into::<HtmlInputElement>(
    );
    match &mut model.page {
        Page::Login(page) => {
            page.login_info.password =
                input_element.value();
        }
        _ => (),
    };
    vdom.schedule_render();
}

fn http_post_with<T: Serialize, D>(path: &str, send: T) -> Option<Promise>
    where for <'a> D: Deserialize<'a> + Serialize {
    let body_js: String = 
        serde_json::to_string(&send).ok()?;
    
    let mut req_init = RequestInit::new();
    req_init.method("POST");
    req_init.mode(RequestMode::SameOrigin);
    req_init.body(Some(&body_js.into()));

    let req = Request::new_with_str_and_init(
        path,
        &req_init
    ).ok()?;

    req.headers()
        .set("Content-Type", "text/json").ok()?;
    
    let window = web_sys::window()?;
    let fut = JsFuture::from(window.fetch_with_request(&req))
        .and_then(|response_value| {
            let response: Response = response_value.dyn_into().unwrap();
            response.json()
        })
        .and_then(|json_value: Promise| {
            JsFuture::from(json_value)
        })
        .and_then(|json| {
            let d: D = json.into_serde().unwrap();
            future::ok(JsValue::from_serde(&d).unwrap())
        });
    Some(future_to_promise(fut))
}

fn http_post<D>(path: &str) -> Option<Promise>
     where for <'a> D: Deserialize<'a> + Serialize {
    let mut req_init = RequestInit::new();
    req_init.method("POST");
    req_init.mode(RequestMode::SameOrigin);

    let req = Request::new_with_str_and_init(
        path,
        &req_init
    ).ok()?;

    let window = web_sys::window()?;
    let fut = JsFuture::from(window.fetch_with_request(&req))
        .and_then(|response_value| {
            let response: Response = response_value.dyn_into().unwrap();
            response.json()
        })
        .and_then(|json_value: Promise| {
            JsFuture::from(json_value)
        })
        .and_then(|json| {
            let d: D = json.into_serde().unwrap();
            future::ok(JsValue::from_serde(&d).unwrap())
        });
    Some(future_to_promise(fut))
}

fn login_submit(
    root: &mut dyn dodrio::RootRender,
    vdom: VdomWeak,
    _: Event,
) {
    let model: &mut Model = root.unwrap_mut::<Model>();
    match &model.page {
        Page::Login(page) => {
            match http_post_with("/sched/login", page.login_info.clone()) {
                Some(promise) => {
                    promise.then(|js_val: JsValue| {
                        model.current_employee = js_val.dyn_into().ok();
                    }
                }
                None => ()
            };
                
            vdom.schedule_render();
        }
        _ => ()
    }
}

fn view_login_page<'a, 'b>(
    model: &Model,
    bump: &'b Bump,
    login_model: &LoginModel,
) -> dodrio::Node<'b> {
    info!("{:#?}", model);
    let mut login_div_style = String::new();
    login_div_style.push_str("width: 95%;");
    login_div_style.push_str("margin: auto;");
    login_div_style.push_str("background-color: #AAAAAA;");
    login_div_style.push_str("padding: 3%");

    dodrio!(bump,
        <div style={login_div_style}>
            <h1 style="text-align: center">
                "Log into scheduler"
            </h1>
            <input
                type="text"
                style="margin: inherit;"
                value={login_model.login_info.email.clone()}
                placeholder="Email"
                oninput={login_update_email}/>
            <input
                type="text"
                style="margin: inherit;"
                value={login_model.login_info.password.clone()}
                placeholder="Password"
                oninput={login_update_password}/>
            <button
                class="submit"
                onclick={login_submit}>"Submit"</button>
        </div>
    )
}

fn calendar_open_nav(
    root: &mut dyn dodrio::RootRender,
    vdom: VdomWeak,
    _: Event) {
    let model = root.unwrap_mut::<Model>();
    match &mut model.page {
        Page::Calendar(page) => {
            page.mode = CalendarMode::Nav;
            vdom.schedule_render();
        }
        _ => ()
    }
}

fn calendar_open_account(
    root: &mut dyn dodrio::RootRender,
    vdom: VdomWeak,
    _: Event) {
    let model = root.unwrap_mut::<Model>();
    match &mut model.page {
        Page::Calendar(page) => {
            page.mode = CalendarMode::Account;
            vdom.schedule_render();
        }
        _ => ()
    }
}

fn calendar_open_views(
    root: &mut dyn dodrio::RootRender,
    vdom: VdomWeak,
    _: Event) {
    let model = root.unwrap_mut::<Model>();
    match &mut model.page {
        Page::Calendar(page) => {
            page.mode = CalendarMode::ViewSelect;
            vdom.schedule_render();
        }
        _ => ()
    }
}

fn calendar_open_config(
    root: &mut dyn dodrio::RootRender,
    vdom: VdomWeak,
    _: Event) {
    let model = root.unwrap_mut::<Model>();
    match &mut model.page {
        Page::Calendar(page) => {
            page.mode = CalendarMode::ViewEdit;
            vdom.schedule_render();
        }
        _ => ()
    }
}

fn calendar_log_out(
    root: &mut dyn dodrio::RootRender,
    vdom: VdomWeak,
    _: Event) {
    http_post::<()>("/sched/logout");
    let model = root.unwrap_mut::<Model>();
    model.current_employee = None;
    vdom.schedule_render();
}

fn calendar_close_modal(
    root: &mut dyn dodrio::RootRender,
    vdom: VdomWeak,
    _: Event) {
    let model = root.unwrap_mut::<Model>();
    match &mut model.page {
        Page::Calendar(page) => {
            page.mode = CalendarMode::NoModal;
            vdom.schedule_render();
        }
        _ => ()
    }
}

fn view_calendar_modal<'a, 'b>(
    model: &'a Model,
    bump: &'b Bump,
    calendar_model: &CalendarModel,
) -> dodrio::Node<'b> {
    dodrio!(bump,
        <div>
            <nav>
                <input
                    type="checkbox"
                    class="show"
                    id="navtoggle"
                    checked={match calendar_model.mode {
                        CalendarMode::Nav => true,
                        _ => false,
                    }}
                    onclick={calendar_open_nav}
                />
                <label
                    for="navtoggle"
                    class="burger pseudo button"
                >"Menu"
                </label>
                <div class="menu">
                    <input class="button" value="Account"
                        onclick={calendar_open_account}/>
                    <input class="button" value="Views"
                        onclick={calendar_open_views}/>
                    <input class="button" value="Configuration"
                        onclick={calendar_open_config}/>
                    <input class="button" value="Log out"
                        onclick={calendar_log_out}/>
                </div>
            </nav>
            <div class="modal">
                <input
                    type="checkbox"
                    id="account_modal"
                    checked={match calendar_model.mode {
                        CalendarMode::Account => true,
                        _ => false,
                    }}/>
                <label
                    for="account_modal"
                    class="overlay"
                    onclick={calendar_close_modal}/>
                <article>
                    <section class="content">
                        "Account Modal"
                    </section>
                </article>
            </div>
        </div>
    )
}

fn view_calendar_day<'a, 'b>(
    model: &'a Model,
    bump: &'b Bump,
    calendar_model: &CalendarModel,
) -> dodrio::Node<'b> {
    unimplemented!()
}

fn view_calendar_day_alt<'a, 'b>(
    model: &'a Model,
    bump: &'b Bump,
    calendar_model: &CalendarModel,
) -> dodrio::Node<'b> {
    unimplemented!()
}

fn view_calendar_week<'a, 'b>(
    model: &'a Model,
    bump: &'b Bump,
    calendar_model: &CalendarModel,
) -> dodrio::Node<'b> {
    unimplemented!()
}

fn view_calendar_month<'a, 'b>(
    model: &'a Model,
    bump: &'b Bump,
    calendar_model: &CalendarModel,
) -> dodrio::Node<'b> {
    unimplemented!()
}

fn view_calendar_page<'a, 'b>(
    model: &'a Model,
    bump: &'b Bump,
    calendar_model: &CalendarModel,
) -> dodrio::Node<'b> {
    dodrio!(bump,
        <div>
        {bumpalo::vec![in bump;
            view_calendar_modal(model, bump, calendar_model),
            match calendar_model.view_mode {
                CalendarView::Day => {
                    view_calendar_day(model, bump, calendar_model)
                }
                CalendarView::DayAlt => {
                    view_calendar_day_alt(model, bump, calendar_model)
                }
                CalendarView::Week => {
                    view_calendar_week(model, bump, calendar_model)
                }
                CalendarView::Month => {
                    view_calendar_month(model, bump, calendar_model)
                }
            }
        ]}
        </div>
    )
}

impl Render for Model {
    fn render<'a, 'b>(
        &'a self,
        bump: &'b Bump,
    ) -> dodrio::Node<'b>
    where
        'a: 'b,
    {
        // log!(self);
        match &self.page {
            Page::Login(page) => {
                view_login_page(self, bump, page)
            }
            Page::Calendar(page) => {
                view_calendar_page(self, bump, page)
            }
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

#[derive(Deserialize, Serialize, Debug, Clone)]
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

// fn update(
//     msg: Message,
//     model: &mut Model,
//     orders: &mut Orders<Message>,
// ) {
//     log!(msg);
//     match (&model.page, &model.current_employee) {
//         (Page::Calendar(_), None) => {
//             let login_page =
//                 Page::Login(LoginModel::default());
//             orders
//                 .send_msg(Message::SwitchPage(login_page));
//         }
//         _ => (),
//     };
//     match (&mut model.page, &msg) {
//         (_, Message::Resize(w, _)) => {
//             model.device_class = classify_device(w);
//         }
//         (_, Message::HttpError(js_value)) => {
//             log!(js_value);
//             model.current_employee = None;
//         }
//         (
//             Page::Login(page),
//             Message::Login(login_message),
//         ) => {
//             match login_message {
//                 LoginMessage::UpdateEmail(email) => {
//                     page.login_info.email = email.clone();
//                 }
//                 LoginMessage::UpdatePassword(password) => {
//                     page.login_info.password =
//                         password.clone();
//                 }
//                 LoginMessage::Login => {
//                     let req = Request::new("/sched/login")
//                         .method(Method::Post)
//                         .header(
//                             "Content-Type",
//                             "text/json;charset=UTF-8",
//                         )
//                         .body_json(&page.login_info)
//                         .fetch_json()
//                         .map(handle_login_result)
//                         .map_err(|_| {
//                             Message::Login(
//                                 LoginMessage::LoginFail,
//                             )
//                         });
//                     orders.skip().perform_cmd(req);
//                 }
//                 LoginMessage::LoginSuccess(employee) => {
//                     model.current_employee =
//                         Some(employee.clone());
//                     let calendar_model = CalendarModel {
//                         mode: CalendarMode::NoModal,
//                         view_mode: CalendarView::Day,
//                     };
//                     orders.send_msg(Message::SwitchPage(
//                         Page::Calendar(calendar_model),
//                     ));
//                 }
//                 LoginMessage::LoginFail => (),
//             }
//         }
//         (
//             Page::Calendar(page),
//             Message::Calendar(CalendarMessage::OpenModal(
//                 mode,
//             )),
//         ) => {
//             page.mode = mode.clone();
//         }
//         (
//             Page::Calendar(page),
//             Message::Calendar(CalendarMessage::CloseModal),
//         ) => {
//             page.mode = CalendarMode::NoModal;
//         }
//         (_, Message::SwitchPage(page)) => {
//             model.page = page.clone();
//             match model.page {
//                 Page::Calendar(_) => {
//                     let req_emps = Request::new(
//                         "/sched/get_employees",
//                     )
//                     .method(Method::Post)
//                     .fetch_json()
//                     .map(Message::ReceiveEmployees)
//                     .map_err(Message::HttpError);
//                     orders.perform_cmd(req_emps);
//                     let req_configs =
//                         Request::new("/sched/get_configs")
//                             .method(Method::Post)
//                             .fetch_json()
//                             .map(Message::ReceiveConfigs)
//                             .map_err(Message::HttpError);
//                     orders.perform_cmd(req_configs);
//                     let req_active_config = Request::new(
//                         "/sched/get_active_config",
//                     )
//                     .method(Method::Post)
//                     .fetch_json()
//                     .map(Message::ReceiveActiveConfig)
//                     .map_err(Message::HttpError);
//                     orders.perform_cmd(req_active_config);
//                     let req_shifts =
//                         Request::new("/sched/get_shifts")
//                             .method(Method::Post)
//                             .fetch_json()
//                             .map(Message::ReceiveShifts)
//                             .map_err(Message::HttpError);
//                     orders.perform_cmd(req_shifts);
//                     let req_shift_exceptions =
//                         Request::new(
//                             "/sched/get_shift_exceptions",
//                         )
//                         .method(Method::Post)
//                         .fetch_json()
//                         .map(
//                             Message::ReceiveShiftExceptions,
//                         )
//                         .map_err(Message::HttpError);
//                     orders
//                         .perform_cmd(req_shift_exceptions);
//                     let req_vacations = Request::new(
//                         "/sched/get_vacations",
//                     )
//                     .method(Method::Post)
//                     .fetch_json()
//                     .map(Message::ReceiveVacations)
//                     .map_err(Message::HttpError);
//                     orders.perform_cmd(req_vacations);
//                 }
//                 _ => (),
//             }
//         }
//         _ => (),
//     }
// }

fn window_width() -> f64 {
    web_sys::window()
        .unwrap()
        .inner_width()
        .ok()
        .unwrap()
        .as_f64()
        .unwrap()
}

fn window_height() -> f64 {
    web_sys::window()
        .unwrap()
        .inner_height()
        .ok()
        .unwrap()
        .as_f64()
        .unwrap()
}

#[wasm_bindgen(start)]
pub fn run() {
    console_error_panic_hook::set_once();
    console_log::init_with_level(Level::Trace)
        .expect("error initializing logging");

    let window = web_sys::window().unwrap();
    let document = window.document().unwrap();
    let body = document.body().unwrap();


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
    

    let vdom = dodrio::Vdom::new(&body, init_model);

    vdom.forget();
}
