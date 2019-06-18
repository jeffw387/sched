#![feature(proc_macro_hygiene)]
#![recursion_limit = "256"]

#[macro_use]
extern crate stdweb;
use chrono::prelude::*;
use chrono::{
    DateTime,
    Datelike,
    NaiveDateTime,
    Timelike,
};
use stdweb::js;
// use http::{
//     header,
//     Request,
//     Response,
// };
use enclose::enclose;
use futures::future::Future;
use js_sys::Promise;
use serde::{
    de::DeserializeOwned,
    Deserialize,
    Serialize,
};
use std::cell::RefCell;
use std::collections::VecDeque;
use std::fmt::{
    Debug,
    Display,
    Formatter,
};
use std::rc::Rc;
use std::result::Result;
use std::sync::{
    Arc,
    Mutex,
};
use virtual_dom_rs::html;
use virtual_dom_rs::prelude::*;
use virtual_dom_rs::VirtualNode;
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;
use wasm_bindgen_futures::{
    future_to_promise,
    JsFuture,
};
use web_sys::{
    Document,
    HtmlElement,
    Request,
    RequestInit,
    RequestMode,
    Response,
    Window,
};

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

impl Default for Employee {
    fn default() -> Self {
        Self {
            id: 0,
            email: String::default(),
            active_config: None,
            level: EmployeeLevel::Read,
            first: String::default(),
            last: String::default(),
            phone_number: None,
            default_color: EmployeeColor::Green,
        }
    }
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

#[derive(Clone, Debug, Deserialize, Serialize)]
struct LoginModel {
    login_info: LoginInfo,
    input_enabled: bool,
}

impl Default for LoginModel {
    fn default() -> Self {
        Self {
            login_info: LoginInfo::default(),
            input_enabled: true,
        }
    }
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

impl Default for CalendarModel {
    fn default() -> Self {
        Self {
            mode: CalendarMode::NoModal,
            view_mode: CalendarView::Day,
        }
    }
}

#[derive(Clone, Debug, Deserialize, Serialize)]
enum Page {
    CheckToken,
    Login(LoginModel),
    Calendar(CalendarModel),
}

impl Default for Page {
    fn default() -> Self {
        Page::Login(LoginModel::default())
    }
}

type CellOpt<T> = Rc<RefCell<Option<T>>>;

struct Model {
    messages: VecDeque<Message>,
    tasks: RefCell<
        Vec<
            Rc<dyn Future<Item = Message, Error = Message>>,
        >,
    >,
    dom: Rc<RefCell<DomUpdater>>,
    configs: CellOpt<Vec<CombinedConfig>>,
    active_config: CellOpt<i32>,
    current_employee: CellOpt<Employee>,
    employees: CellOpt<Vec<Employee>>,
    shifts: CellOpt<Vec<Shift>>,
    shift_exceptions: CellOpt<Vec<ShiftException>>,
    vacations: CellOpt<Vec<Vacation>>,
    view_date: CellOpt<DateTime<Utc>>,
    page: RefCell<Page>,
    device_class: RefCell<DeviceClass>,
}

fn update_dom(
    model: Arc<Mutex<Model>>,
    vnode: VirtualNode,
) {
    model.lock().unwrap().dom.borrow_mut().update(vnode);
}

fn process_messages(model: Arc<Mutex<Model>>) -> bool {
    let mut should_render = false;
    loop {
        match model.get_mut().unwrap().messages.pop_front()
        {
            Some(msg) => {
                let (render, msgs) =
                    update(model.clone(), msg);
                for update_msg in msgs {
                    queue_message(
                        Arc::clone(&model),
                        update_msg,
                    );
                }
                if render {
                    should_render = true;
                }
            }
            None => return should_render,
        }
    }
}

impl Debug for Model {
    fn fmt(&self, f: &mut Formatter) -> std::fmt::Result {
        // match self.configs_fetch {
        //     Some(_) => writeln!(f, "configs_fetch active")?,
        //     None => ()
        // };
        // match self.active_config_fetch {
        //     Some(_) => writeln!(f, "active_config_fetch active")?,
        //     None => ()
        // };
        // match self.login_fetch {
        //     Some(_) => writeln!(f, "login_fetch active")?,
        //     None => ()
        // };
        // match self.employees_fetch {
        //     Some(_) => writeln!(f, "employees_fetch active")?,
        //     None => ()
        // };
        // match self.shifts_fetch {
        //     Some(_) => writeln!(f, "shifts_fetch active")?,
        //     None => ()
        // };
        // match self.shift_exceptions_fetch {
        //     Some(_) => writeln!(f, "shift_exceptions_fetch active")?,
        //     None => ()
        // };
        // match self.vacations_fetch {
        //     Some(_) => writeln!(f, "vacations_fetch active")?,
        //     None => ()
        // };
        match &*self.configs.borrow() {
            Some(c) => {
                writeln!(f, "configs loaded: {}", c.len())?
            }
            None => (),
        };
        match &*self.active_config.borrow() {
            Some(_) => writeln!(f, "active config loaded")?,
            None => (),
        };
        match &*self.current_employee.borrow() {
            Some(_) => {
                writeln!(f, "current employee loaded")?
            }
            None => (),
        };
        match &*self.employees.borrow() {
            Some(e) => {
                writeln!(
                    f,
                    "employees loaded: {}",
                    e.len()
                )?
            }
            None => (),
        };
        match &*self.shifts.borrow() {
            Some(e) => {
                writeln!(f, "shifts loaded: {}", e.len())?
            }
            None => (),
        };
        match &*self.shift_exceptions.borrow() {
            Some(e) => {
                writeln!(
                    f,
                    "shift exceptions loaded: {}",
                    e.len()
                )?
            }
            None => (),
        };
        match &*self.vacations.borrow() {
            Some(e) => {
                writeln!(
                    f,
                    "vacations loaded: {}",
                    e.len()
                )?
            }
            None => (),
        };
        match &*self.view_date.borrow() {
            Some(dt) => {
                writeln!(
                    f,
                    "view date is {}",
                    dt.to_rfc2822()
                )?
            }
            None => (),
        };

        writeln!(
            f,
            "current_employee: {:#?}",
            self.current_employee
        )?;

        match &*self.page.borrow() {
            Page::CheckToken => {
                writeln!(f, "Page::CheckToken")?
            }
            Page::Login(page) => {
                writeln!(f, "Page::Login")?;
                write!(f, "{:#?}", page)?;
                writeln!(f)?;
            }
            Page::Calendar(page) => {
                writeln!(f, "Page::Calendar")?;
                write!(f, "{:#?}", page)?;
                writeln!(f)?;
            }
        };

        writeln!(
            f,
            "DeviceClass: {:?}",
            &self.device_class
        )?;
        Ok(())
    }
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
    LoginSuccess(Option<LoginResult>),
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

enum Message {
    NoOp,
    TokenSuccess(Option<Employee>),
    TokenFailure,
    Resize(f64, f64),
    SwitchPage(Page),
    // HttpError(JsValue),
    Logout,
    LogoutResponse(bool),
    // KeyDown,
    Account(AccountMessage),
    Login(LoginMessage),
    Calendar(CalendarMessage),
    EmployeeEdit(EmployeeEditMessage),
    AddEvent(AddEventMessage),
    Shift(ShiftMessage),
    ConfigEdit(ConfigEditMessage),
    FetchData,
    ReceiveEmployees(Option<JsonObject<Vec<Employee>>>),
    ReceiveShifts(Option<JsonObject<Vec<Shift>>>),
    ReceiveShiftExceptions(
        Option<JsonObject<Vec<ShiftException>>>,
    ),
    ReceiveVacations(Option<JsonObject<Vec<Vacation>>>),
    ReceiveActiveConfig(Option<JsonObject<Option<i32>>>),
    ReceiveConfigs(Option<JsonObject<Vec<CombinedConfig>>>),
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

enum HttpError {
    Js(JsValue),
    Serde(serde_json::Error),
}

fn dt_in_range(
    dt: DateTime<Utc>,
    start: DateTime<Utc>,
    end: DateTime<Utc>,
) -> bool {
    let a = dt >= start;
    let b = dt <= end;
    a && b
}

impl Shift {
    fn overlaps_with_day(
        &self,
        day: DateTime<Utc>,
    ) -> bool {
        let old_dur =
            match chrono::Duration::from_std(self.duration)
            {
                Ok(d) => d,
                Err(_) => return false,
            };
        let start = self.start;
        let end = start + old_dur;
        let day_plus_one =
            day + chrono::Duration::hours(24);
        let start_within =
            dt_in_range(start, day, day_plus_one);
        let end_within =
            dt_in_range(end, day, day_plus_one);
        start_within || end_within
    }
}

struct Callback<T: 'static>(Rc<dyn Fn(T) -> Message>);

impl<T, F: (Fn(T) -> Message) + 'static> From<F>
    for Callback<T>
{
    fn from(func: F) -> Self {
        Callback(Rc::new(func))
    }
}

impl<T> Callback<T> {
    pub fn invoke(&self, value: T) -> Message {
        (self.0)(value)
    }
}

fn http_post_with<I, O>(
    // model: Arc<Mutex<Model>>,
    path: &str,
    input: &I,
    success: Callback<Option<O>>,
    failure: Callback<()>,
) -> Result<
    Rc<dyn Future<Item = Message, Error = Message>>,
    HttpError,
>
where
    I: Serialize,
    O: DeserializeOwned,
{
    let body = serde_json::to_string(&input)
        .map(|s| {
            let j: JsValue = s.into();
            j
        })
        .map_err(HttpError::Serde)?;

    let mut req_init = RequestInit::new();
    req_init.method("POST").body(Some(&body));

    let req =
        Request::new_with_str_and_init(path, &req_init)
            .map_err(HttpError::Js)?;
    req.headers()
        .set("Content-Type", "text/json")
        .map_err(HttpError::Js)?;

    let req_promise =
        JsFuture::from(window().fetch_with_request(&req))
            .and_then(move |resolve: JsValue| {
                let response: Response =
                    resolve.dyn_into().unwrap();
                let f = JsFuture::from(
                    response.text().unwrap(),
                );
                f
            })
            .map(move |text| {
                let o: Option<O> = serde_json::from_str(
                    &text.as_string().unwrap(),
                )
                .ok();
                success.invoke(o)
            })
            .map_err(move |_| failure.invoke(()));
    Ok(Rc::new(req_promise))
}

fn view_check_token_page(
    model: Arc<Mutex<Model>>,
) -> VirtualNode {
    html! {<p>{"Authenticating..."}</p>}
}

fn target_string(e: web_sys::Event) -> Option<String> {
    let target = e.target()?;
    let target_value: JsValue = target.dyn_into().ok()?;
    target_value.as_string()
}

fn view_login_page(
    model: Arc<Mutex<Model>>,
    login_model: &LoginModel,
) -> VirtualNode {
    let update_email_closure = enclose!((model) move|e: web_sys::Event| {
        queue_message(model,
            Message::Login(
                LoginMessage::UpdateEmail(
                    target_string(e).unwrap())));
    });

    let update_password_closure = enclose!((model) move|e| {
        queue_message(model,
            Message::Login(
                LoginMessage::UpdatePassword(
                    target_string(e).unwrap())));
    });

    let submit_closure = enclose!((model) move|_: web_sys::Event| {
        queue_message(model,
            Message::Login(LoginMessage::Login));
    });

    html! {
        <fieldset style="width: 95%; margin: auto; background-color: #AAAAAA; padding: 3%;">
            <h1 style="text-align: center">
                {"Log into scheduler"}
            </h1>
            <input
                type="text"
                style="margin: inherit"
                value={login_model.login_info.email.clone()}
                placeholder="Email"
                oninput=|e| update_email_closure(e) />
            <input
                type="password"
                style="margin: inherit"
                value={login_model.login_info.password.clone()}
                placeholder="Password"
                oninput=|e| update_password_closure(e) />
            <button
                class="submit"
                onclick=|e| submit_closure(e)>{"Submit"}</button>
        </fieldset>
    }
}

fn queue_message(model: Arc<Mutex<Model>>, msg: Message) {
    model.lock().unwrap().messages.push_back(msg);
}

fn view_calendar_modal(
    model: Arc<Mutex<Model>>,
    calendar_model: &CalendarModel,
) -> VirtualNode {
    let open_nav_closure = enclose!((model) move|_: web_sys::Event| {
        let msg = Message::Calendar(
            CalendarMessage::OpenModal(CalendarMode::Nav));
        queue_message(model, msg);
    });

    let open_account_closure = enclose!((model) move|_: web_sys::Event| {
        queue_message(model,
            Message::Calendar(
                CalendarMessage::OpenModal(
                    CalendarMode::Account)));
    });

    let open_views_closure = enclose!((model) move|_: web_sys::Event| {
        queue_message(model,
            Message::Calendar(
                CalendarMessage::OpenModal(
                    CalendarMode::ViewSelect)));
    });

    let open_config_closure = enclose!((model) move|_: web_sys::Event| {
        queue_message(model,
            Message::Calendar(
                CalendarMessage::OpenModal(
                    CalendarMode::ViewEdit)));
    });

    let logout_closure = enclose!((model) move|_: web_sys::Event| {
                            queue_message(model, Message::Logout);});

    let close_modal_closure = enclose!((model) move|_: web_sys::Event| {
        let msg = Message::Calendar(CalendarMessage::CloseModal);
        queue_message(model, msg);
    });

    html! {
        <div>
            <nav>
                <input
                    type="checkbox"
                    class="show"
                    id="navtoggle"
                    checked={match calendar_model.mode {
                        CalendarMode::Nav => true,
                        _ => false
                    }}
                    onclick=|e| open_nav_closure(e)
                />
                <label r#for="navtoggle" class="burger pseudo button">
                {"Menu"}
                </label>
                <div class="menu">
                    <input class="button" value="Account"
                        onclick=|e| open_account_closure(e)/>
                    <input class="button" value="Views"
                        onclick=|e| open_views_closure(e)/>
                    <input class="button" value="Configuration"
                        onclick=|e| open_config_closure(e)/>
                    <input class="button" value="Log out"
                        onclick=|e| logout_closure(e)/>
                </div>
            </nav>
            <div class="modal">
                <input
                    type="checkbox"
                    id="account_modal"
                    checked={match calendar_model.mode {
                        CalendarMode::Account => true,
                        _ => false
                    }}/>
                <label
                    r#for="account_modal"
                    class="overlay"
                    onclick=|e| close_modal_closure(e)>
                </label>
                <article>
                    <section class="content">
                        {"Account Modal"}
                    </section>
                </article>
            </div>
        </div>
    }
}

fn view_calendar_day(
    // model: Arc<Mutex<Model>>,
    shifts_opt: Option<Vec<Shift>>,
    view_date_opt: Option<DateTime<Utc>>,
    calendar_model: &CalendarModel,
) -> VirtualNode {
    // self.console.info("view_calendar_day");
    let empty = vec![];
    // let inner_model: &Model = &*model.lock().unwrap();
    // let shifts_opt: &Option<Vec<Shift>> = &*inner_model.shifts.borrow();
    let shifts: &Vec<Shift> =
        shifts_opt.as_ref().unwrap_or(&empty);

    // let view_date_opt: &Option<DateTime<Utc>> = &*inner_model.view_date.borrow();
    let view_date: DateTime<Utc> = match view_date_opt {
        Some(dt) => dt,
        None => {
            return html! {
                <div>{"An error occurred..."}</div>
            };
        }
    };
    let shifts_today = shifts
        .into_iter()
        .filter(|s| s.overlaps_with_day(view_date));
    html! {
        <div>{"Day View"}</div>
    }
}

fn view_calendar_day_alt(
    // model: Arc<Mutex<Model>>,
    calendar_model: &CalendarModel,
) -> VirtualNode {
    unimplemented!()
}

fn view_calendar_week(
    // model: Arc<Mutex<Model>>,
    calendar_model: &CalendarModel,
) -> VirtualNode {
    unimplemented!()
}

fn view_calendar_month(
    // model: Arc<Mutex<Model>>,
    calendar_model: &CalendarModel,
) -> VirtualNode {
    unimplemented!()
}

fn view_calendar_page(
    model: Arc<Mutex<Model>>,
    calendar_model: &CalendarModel,
) -> VirtualNode {
    html! {
        <div>
            {view_calendar_modal(Arc::clone(&model), calendar_model)}
            {match calendar_model.view_mode {
                CalendarView::Day => {
                    view_calendar_day(
                        model.lock().unwrap().shifts.borrow().clone(),
                        model.lock().unwrap().view_date.borrow().clone(),
                        calendar_model)
                }
                CalendarView::DayAlt => {
                    view_calendar_day_alt(calendar_model)
                }
                CalendarView::Week => {
                    view_calendar_week(calendar_model)
                }
                CalendarView::Month => {
                    view_calendar_month(calendar_model)
                }
            }}
        </div>
    }
}

impl Default for Model {
    fn default() -> Self {
        let now = js! {
            var now = Date.now();
            return now;
        };
        let now = match now {
            stdweb::Value::Number(n) => {
                let dbl: f64 = n.into();
                dbl
            }
            _ => panic!("Error getting date from JS!"),
        };
        let naive_dt = NaiveDateTime::from_timestamp(
            (now / 1000.0) as i64,
            0,
        );
        let utc_dt =
            DateTime::<Utc>::from_utc(naive_dt, Utc);

        let initial_dom = html! {<p>Initial Dom</p>};

        Model {
            messages: VecDeque::default(),
            tasks: RefCell::new(Vec::new()),
            dom: Rc::new(RefCell::new(
                DomUpdater::new_append_to_mount(
                    initial_dom,
                    &body(),
                ),
            )),
            configs: Rc::new(RefCell::new(None)),
            active_config: Rc::new(RefCell::new(None)),
            current_employee: Rc::new(RefCell::new(None)),
            employees: Rc::new(RefCell::new(None)),
            shifts: Rc::new(RefCell::new(None)),
            shift_exceptions: Rc::new(RefCell::new(None)),
            vacations: Rc::new(RefCell::new(None)),
            view_date: Rc::new(RefCell::new(Some(utc_dt))),
            page: RefCell::new(Page::CheckToken),
            device_class: RefCell::new(
                DeviceClass::default(),
            ),
        }
    }
}

fn update(
    model: Arc<Mutex<Model>>,
    msg: Message,
) -> (bool, Vec<Message>) {
    let model_inner = &mut model.get_mut().unwrap();
    let mut_page: &mut Page =
        &mut model_inner.page.borrow_mut();
    let mut replies = vec![];
    match (mut_page, &msg) {
        (_, Message::Resize(w, _)) => {
            // model.console.info(&format!("Resize message: width {:?}", w));
            let _ = model_inner
                .device_class
                .replace(classify_device(w));
            // model.console.info(&format!("Device class: {}", model.device_class));
        }
        (
            Page::CheckToken,
            Message::TokenSuccess(employee_opt),
        ) => {
            model_inner
                .current_employee
                .replace(employee_opt.clone());
            replies.push(Message::SwitchPage(
                Page::Calendar(CalendarModel::default()),
            ));
        }
        (_, Message::TokenFailure) => {
            model_inner.current_employee.replace(None);
            replies.push(Message::SwitchPage(Page::Login(
                LoginModel::default(),
            )));
        }
        (
            Page::Login(page),
            Message::Login(login_message),
        ) => {
            match login_message {
                LoginMessage::UpdateEmail(email) => {
                    // model.console.info("Update login email");
                    page.login_info.email = email.clone();
                }
                LoginMessage::UpdatePassword(password) => {
                    // model.console.info("Update login password");
                    page.login_info.password =
                        password.clone();
                }
                LoginMessage::Login => {
                    // model.console.info("Login");
                    page.input_enabled = false;
                    let _ = http_post_with(
                        // model.clone(),
                        "/sched/login",
                        &page.login_info,
                        Callback::from(|e| {
                            Message::Login(
                                LoginMessage::LoginSuccess(
                                    e,
                                ),
                            )
                        }),
                        Callback::from(|_| {
                            Message::Login(
                                LoginMessage::LoginFail,
                            )
                        }),
                    );
                }
                LoginMessage::LoginSuccess(result) => {
                    // model.console.info(&format!("LoginSuccess, employee: {:?}", result));
                    // model.login_fetch = None;
                    model_inner.current_employee.replace(
                        match result {
                            Some(result) => {
                                result.employee.clone()
                            }
                            None => None,
                        },
                    );
                    let calendar_model = CalendarModel {
                        mode: CalendarMode::NoModal,
                        view_mode: CalendarView::Day,
                    };
                    model_inner
                        .messages
                        .push_back(Message::FetchData);
                    model_inner.messages.push_back(
                        Message::SwitchPage(
                            Page::Calendar(calendar_model),
                        ),
                    );
                }
                LoginMessage::LoginFail => {
                    // model.console.info("LoginFail");
                    // model.login_fetch = None;
                    model_inner.page.replace(Page::Login(
                        LoginModel::default(),
                    ));
                }
            }
        }
        (
            Page::Calendar(page),
            Message::Calendar(CalendarMessage::OpenModal(
                mode,
            )),
        ) => {
            // model.console.info(&format!("Open modal {:?}", mode));
            page.mode = mode.clone();
        }
        (
            Page::Calendar(page),
            Message::Calendar(CalendarMessage::CloseModal),
        ) => {
            // model.console.info("Close modal");
            page.mode = CalendarMode::NoModal;
        }
        (_, Message::FetchData) => {
            // model.console.info("Fetch data from server");
            let _ = http_post_with(
                // model.clone(),
                "/sched/get_employees",
                &(),
                Callback::from(|res| {
                    Message::ReceiveEmployees(res)
                }),
                Callback::from(|_| Message::NoOp),
            );
            let _ = http_post_with(
                // model.clone(),
                "/sched/get_configs",
                &(),
                Callback::from(|res| {
                    Message::ReceiveConfigs(res)
                }),
                Callback::from(|_| Message::NoOp),
            );
            let _ = http_post_with(
                // model.clone(),
                "/sched/get_active_config",
                &(),
                Callback::from(|res| {
                    Message::ReceiveActiveConfig(res)
                }),
                Callback::from(|_| Message::NoOp),
            );
            let _ = http_post_with(
                // model.clone(),
                "/sched/get_shifts",
                &(),
                Callback::from(|res| {
                    Message::ReceiveShifts(res)
                }),
                Callback::from(|_| Message::NoOp),
            );
            let _ = http_post_with(
                // model.clone(),
                "/sched/get_shifts",
                &(),
                Callback::from(|res| {
                    Message::ReceiveShifts(res)
                }),
                Callback::from(|_| Message::NoOp),
            );
            let _ = http_post_with(
                // model.clone(),
                "/sched/get_shift_exceptions",
                &(),
                Callback::from(|res| {
                    Message::ReceiveShiftExceptions(res)
                }),
                Callback::from(|_| Message::NoOp),
            );
            let _ = http_post_with(
                // model.clone(),
                "/sched/get_vacations",
                &(),
                Callback::from(|res| {
                    Message::ReceiveVacations(res)
                }),
                Callback::from(|_| Message::NoOp),
            );
        }
        (_, Message::SwitchPage(page)) => {
            // model.console.info(&format!("Switch page to {:?}", page));
            model_inner.page.replace(page.clone());
        }

        _ => (),
    };
    // info(&format!("post-update model: {:?}", self));
    (true, replies)
}

fn view(model: Arc<Mutex<Model>>) -> VirtualNode {
    // let model_inner = &*model.lock().unwrap();
    // let borrowed_page: &Page = &model.lock().unwrap().page.borrow();
    use std::ops::Deref;
    let body = html! {
        <div>
        {
            match model.lock().unwrap().page.borrow().deref() {
                Page::CheckToken => {
                    view_check_token_page(model.clone())
                }
                Page::Login(page) => {
                    view_login_page(model.clone(), &page)
                }
                Page::Calendar(page) => {
                    view_calendar_page(model.clone(), &page)
                }
            }
        }
        </div>
    };
    body
}

fn classify_device(w: &f64) -> DeviceClass {
    match *w as i32 {
        0..=600 => DeviceClass::Mobile,
        601..=1000 => DeviceClass::HalfDesktop,
        _ => DeviceClass::Desktop,
    }
}

#[derive(Deserialize, Serialize, Debug, Clone)]
struct LoginResult {
    employee: Option<Employee>,
}

fn window() -> Window {
    web_sys::window().expect("Unable to get window!")
}

fn document() -> Document {
    window().document().expect("Unable to get document!")
}

fn body() -> HtmlElement {
    document()
        .body()
        .expect("Unable to get document body element!")
}

pub fn main() {
    let model: Arc<Mutex<Model>> =
        Arc::new(Mutex::new(Model::default()));
    loop {
        {
            let filtered = model
                .lock()
                .unwrap()
                .tasks
                .borrow_mut()
                .iter_mut()
                .filter_map(|task| {
                    match Rc::get_mut(task).poll() {
                        Ok(ready) => match ready {
                            futures::Async::NotReady => {
                                None
                            }
                            futures::Async::Ready(
                                msg_opt,
                            ) => {
                                match msg_opt {
                                    Some(msg) => {
                                        queue_message(
                                            Arc::clone(
                                                &model,
                                            ),
                                            msg,
                                        );
                                        None
                                    }
                                    None => None,
                                }
                            }
                        },
                        Err(_) => Some(task),
                    }
                })
                .map(|task| {
                    let task: Rc<
                        dyn Future<
                            Item = Message,
                            Error = Message,
                        >,
                    > = task.clone();
                    task
                })
                .collect();
            model.lock().unwrap().tasks.replace(filtered);
        }
        let should_render = process_messages(model.clone());
        if should_render {
            let vnode = view(model.clone());
            update_dom(model.clone(), vnode);
        }
    }
}
