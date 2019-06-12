#![recursion_limit = "256"]

#[macro_use]
extern crate stdweb;
use stdweb::js;
use chrono::prelude::*;
use chrono::{
    DateTime,
    NaiveDateTime,
    Datelike,
    Timelike,
};
use http::{
    header,
    Request,
    Response,
};
use log::*;
use serde::{
    de::DeserializeOwned,
    Deserialize,
    Serialize,
};
use std::fmt::{Display, Debug, Formatter};
use std::result::Result;
use yew::{
    format::{
        Json,
        Text,
    },
    html,
    html::InputData,
    services::{
        fetch::FetchTask,
        FetchService,
        ConsoleService,
    },
    Component,
    ComponentLink,
    Html,
    Renderable,
    ShouldRender,
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
            view_mode: CalendarView::Day
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

struct Model {
    console: ConsoleService,
    fetch_service: FetchService,
    link: ComponentLink<Self>,
    configs_fetch: Option<FetchTask>,
    configs: Option<Vec<CombinedConfig>>,
    active_config_fetch: Option<FetchTask>,
    active_config: Option<i32>,
    login_fetch: Option<FetchTask>,
    current_employee: Option<Employee>,
    employees_fetch: Option<FetchTask>,
    employees: Option<Vec<Employee>>,
    shifts_fetch: Option<FetchTask>,
    shifts: Option<Vec<Shift>>,
    shift_exceptions_fetch: Option<FetchTask>,
    shift_exceptions: Option<Vec<ShiftException>>,
    vacations_fetch: Option<FetchTask>,
    vacations: Option<Vec<Vacation>>,
    current_date_time: Option<DateTime<Utc>>,
    view_date: Option<DateTime<Utc>>,
    page: Page,
    device_class: DeviceClass,
}

impl Debug for Model {
    fn fmt(&self, f: &mut Formatter) -> std::fmt::Result {
        match self.configs_fetch {
            Some(_) => writeln!(f, "configs_fetch active")?,
            None => ()
        };
        match self.active_config_fetch {
            Some(_) => writeln!(f, "active_config_fetch active")?,
            None => ()
        };
        match self.login_fetch {
            Some(_) => writeln!(f, "login_fetch active")?,
            None => ()
        };
        match self.employees_fetch {
            Some(_) => writeln!(f, "employees_fetch active")?,
            None => ()
        };
        match self.shifts_fetch {
            Some(_) => writeln!(f, "shifts_fetch active")?,
            None => ()
        };
        match self.shift_exceptions_fetch {
            Some(_) => writeln!(f, "shift_exceptions_fetch active")?,
            None => ()
        };
        match self.vacations_fetch {
            Some(_) => writeln!(f, "vacations_fetch active")?,
            None => ()
        };
        match &self.configs {
            Some(c) => writeln!(f, "configs loaded: {}", c.len())?,
            None => ()
        };
        match self.active_config {
            Some(_) => writeln!(f, "active config loaded")?,
            None => ()
        };
        match self.current_employee {
            Some(_) => writeln!(f, "current employee loaded")?,
            None => ()
        };
        match &self.employees {
            Some(e) => writeln!(f, "employees loaded: {}", e.len())?,
            None => ()
        };
        match &self.shifts {
            Some(e) => writeln!(f, "shifts loaded: {}", e.len())?,
            None => ()
        };
        match &self.shift_exceptions {
            Some(e) => writeln!(f, "shift exceptions loaded: {}", e.len())?,
            None => ()
        };
        match &self.vacations {
            Some(e) => writeln!(f, "vacations loaded: {}", e.len())?,
            None => ()
        };
        match &self.view_date {
            Some(dt) => writeln!(f, "view date is {}", dt.to_rfc2822())?,
            None => ()
        };

        writeln!(f, "current_employee: {:#?}", self.current_employee)?;

        match &self.page {
            Page::CheckToken => writeln!(f, "Page::CheckToken")?,
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

        writeln!(f, "DeviceClass: {:?}", &self.device_class)?;
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

fn info(s: &str) {
    let mut console = ConsoleService::new();
    console.info(s);
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

fn http_post_with<I, O, SF, FF>(
    fetch_service: &mut FetchService,
    link: &mut ComponentLink<Model>,
    path: &str,
    input: &I,
    sf: SF,
    ff: FF,
) -> Option<FetchTask>
where
    I: Serialize,
    O: DeserializeOwned,
    SF: (Fn(Option<O>) -> Message) + 'static,
    FF: (Fn() -> Message) + 'static,
{
    let req = Request::post(path)
        .header("Content-Type", "text/json")
        .body(Json(input))
        .ok()?;


    Some(fetch_service.fetch(
        req,
        link.send_back(move |response: Response<Text>| {
            let (meta, text) = response.into_parts();
            match meta.status.is_success() {
                true => {
                    info("http_post_with: success");
                    match text {
                        Ok(s) => {
                            info(&format!("text success: {:?}", s));
                            let j: Option<O> =
                                match serde_json::from_str(&s) {
                                    Ok(j) => Some(j),
                                    Err(e) => {
                                        info(&format!("serde error: {:?}", e));
                                        None
                                    }
                                };
                            sf(j)
                        }
                        Err(e) => {
                            info(&format!("text error: {:?}", e));
                            ff()
                        }
                    }
                }
                false => {
                    info("http_post_with: failure");
                    ff()
                }
            }
        }),
    ))
}

fn http_post<O, SF, FF>(
    fetch_service: &mut FetchService,
    link: &mut ComponentLink<Model>,
    path: &str,
    sf: SF,
    ff: FF,
) -> Option<FetchTask>
where
    O: DeserializeOwned,
    SF: (Fn(Option<O>) -> Message) + 'static,
    FF: (Fn() -> Message) + 'static,
{
    let req = Request::post(path)
        .header("Content-Type", "text/plain")
        .body(Ok(String::default()))
        .ok()?;

    Some(fetch_service.fetch(
        req,
        link.send_back(move |response: Response<Text>| {
            let (meta, text) = response.into_parts();
            match meta.status.is_success() {
                true => {
                    match text.ok() {
                        Some(s) => {
                            let j: Option<O> =
                                serde_json::from_str(&s)
                                    .ok();
                            sf(j)
                        }
                        None => ff(),
                    }
                }
                false => ff(),
            }
        }),
    ))
}

fn dt_in_range(
    dt: DateTime<Utc>, 
    start: DateTime<Utc>, 
    end: DateTime<Utc>) -> bool {
        let a = dt >= start;
        let b = dt <= end;
        a && b
}

impl Shift {
    fn overlaps_with_day(&self, day: DateTime<Utc>) -> bool {
        let old_dur = match chrono::Duration::from_std(self.duration) {
            Ok(d) => d,
            Err(_) => return false
        };
        let start = self.start;
        let end = start + old_dur;
        let day_plus_one = day + chrono::Duration::hours(24);
        let start_within = dt_in_range(start, day, day_plus_one);
        let end_within = dt_in_range(end, day, day_plus_one);
        start_within || end_within
    }
}

impl Model {
    fn view_login_page(
        &self,
        login_model: &LoginModel,
    ) -> Html<Model> {
        html! {
            <fieldset style="width: 95%; margin: auto; background-color: #AAAAAA; padding: 3%;",>
                <h1 style="text-align: center",>
                    {"Log into scheduler"}
                </h1>
                <input
                    type="text",
                    style="margin: inherit",
                    value={login_model.login_info.email.clone()},
                    placeholder="Email",
                    oninput=|e| Message::Login(LoginMessage::UpdateEmail(e.value)), />
                <input
                    type="password",
                    style="margin: inherit",
                    value={login_model.login_info.password.clone()},
                    placeholder="Password",
                    oninput=|e| Message::Login(LoginMessage::UpdatePassword(e.value)), />
                <button
                    class="submit",
                    onclick=|_| Message::Login(LoginMessage::Login),>{"Submit"}</button>
            </fieldset>
        }
    }

    fn view_calendar_modal(
        &self,
        calendar_model: &CalendarModel,
    ) -> Html<Model> {
        html! {
            <div>
                <nav>
                    <input
                        type="checkbox",
                        class="show",
                        id="navtoggle",
                        checked={match calendar_model.mode {
                            CalendarMode::Nav => true,
                            _ => false,
                        }},
                        onclick=|_| Message::Calendar(CalendarMessage::OpenModal(CalendarMode::Nav)),
                    />
                    <label
                        for="navtoggle",
                        class="burger pseudo button",
                    >{"Menu"}
                    </label>
                    <div class="menu",>
                        <input class="button", value="Account",
                            onclick=|_| Message::Calendar(CalendarMessage::OpenModal(CalendarMode::Account)),/>
                        <input class="button", value="Views",
                            onclick=|_| Message::Calendar(CalendarMessage::OpenModal(CalendarMode::ViewSelect)),/>
                        <input class="button", value="Configuration",
                            onclick=|_| Message::Calendar(CalendarMessage::OpenModal(CalendarMode::ViewEdit)),/>
                        <input class="button", value="Log out",
                            onclick=|_| Message::Logout,/>
                    </div>
                </nav>
                <div class="modal",>
                    <input
                        type="checkbox",
                        id="account_modal",
                        checked={match calendar_model.mode {
                            CalendarMode::Account => true,
                            _ => false,
                        }},/>
                    <label
                        for="account_modal",
                        class="overlay",
                        onclick=|_| Message::Calendar(CalendarMessage::CloseModal),/>
                    <article>
                        <section class="content",>
                            {"Account Modal"}
                        </section>
                    </article>
                </div>
            </div>
        }
    }



    fn view_calendar_day(
        &self,
        calendar_model: &CalendarModel,
    ) -> Html<Model> {
        // self.console.info("view_calendar_day");
        let empty = vec![];
        let shifts = self.shifts.as_ref().unwrap_or(&empty);
        let view_date = match self.view_date {
            Some(dt) => dt,
            None => return html!{
                <div>{"An error occurred..."}</div>
            }
        };
        let shifts_today = shifts.into_iter().filter(|s| s.overlaps_with_day(view_date));
        html!{
            <div>{"Day View"}</div>
        }
    }

    fn view_calendar_day_alt(
        &self,
        calendar_model: &CalendarModel,
    ) -> Html<Model> {
        unimplemented!()
    }

    fn view_calendar_week(
        &self,
        calendar_model: &CalendarModel,
    ) -> Html<Model> {
        unimplemented!()
    }

    fn view_calendar_month(
        &self,
        calendar_model: &CalendarModel,
    ) -> Html<Model> {
        unimplemented!()
    }

    fn view_calendar_page(
        &self,
        calendar_model: &CalendarModel,
    ) -> Html<Model> {
        html! {
            <div>
                {self.view_calendar_modal(calendar_model)}
                {match calendar_model.view_mode {
                    CalendarView::Day => {
                        self.view_calendar_day(calendar_model)
                    }
                    CalendarView::DayAlt => {
                        self.view_calendar_day_alt(calendar_model)
                    }
                    CalendarView::Week => {
                        self.view_calendar_week(calendar_model)
                    }
                    CalendarView::Month => {
                        self.view_calendar_month(calendar_model)
                    }
                }}
            </div>
        }
    }
}

impl Component for Model {
    type Message = Message;
    type Properties = ();

    fn create(
        _: Self::Properties,
        link: ComponentLink<Self>,
    ) -> Self {
        // let login_model = LoginModel::default();
        let now = js!{
            var now = Date.now();
            return now;
        };
        let now = match now {
            stdweb::Value::Number(n) => {
                let dbl: f64 = n.into();
                dbl
            }
            _ => panic!("Error getting date from JS!")
        };
        let naive_dt = NaiveDateTime::from_timestamp((now / 1000.0) as i64, 0);
        let utc_dt = DateTime::<Utc>::from_utc(naive_dt, Utc);

        let mut fetch_service = FetchService::new();
        let mut link = link;

        let token_check = http_post(
            &mut fetch_service, 
            &mut link, "/sched/check_token",
            |e| Message::TokenSuccess(e),
            || Message::TokenFailure);

        Model {
            console: ConsoleService::new(),
            fetch_service: fetch_service,
            link,
            configs_fetch: None,
            configs: None,
            active_config_fetch: None,
            active_config: None,
            login_fetch: token_check,
            current_employee: None,
            employees_fetch: None,
            employees: None,
            shifts_fetch: None,
            shifts: None,
            shift_exceptions_fetch: None,
            shift_exceptions: None,
            vacations_fetch: None,
            vacations: None,
            current_date_time: Some(utc_dt),
            view_date: Some(utc_dt),
            page: Page::CheckToken,
            device_class: DeviceClass::default(),
        }
    }

    fn update(
        &mut self,
        msg: Self::Message,
    ) -> ShouldRender {
        match (&mut self.page, &msg) {
            (_, Message::Resize(w, _)) => {
                self.console.info(&format!("Resize message: width {:?}", w));
                self.device_class = classify_device(w);
                self.console.info(&format!("Device class: {}", self.device_class));
            }
            (Page::CheckToken, Message::TokenSuccess(employee_opt)) => {
                self.current_employee = employee_opt.clone();
                self.link.send_self(Message::SwitchPage(Page::Calendar(CalendarModel::default())));
            }
            (_, Message::TokenFailure) => {
                self.current_employee = None;
                self.link.send_self(Message::SwitchPage(Page::Login(LoginModel::default())))
            }
            (
                Page::Login(page),
                Message::Login(login_message),
            ) => {
                match login_message {
                    LoginMessage::UpdateEmail(email) => {
                        self.console.info("Update login email");
                        page.login_info.email =
                            email.clone();
                    }
                    LoginMessage::UpdatePassword(
                        password,
                    ) => {
                        self.console.info("Update login password");
                        page.login_info.password =
                            password.clone();
                    }
                    LoginMessage::Login => {
                        self.console.info("Login");
                        page.input_enabled = false;
                        self.login_fetch = http_post_with(
                            &mut self.fetch_service,
                            &mut self.link,
                            "/sched/login",
                            &page.login_info,
                            |e| {
                                Message::Login(LoginMessage::LoginSuccess(e))
                            },
                            || {
                                Message::Login(
                                    LoginMessage::LoginFail,
                                )
                            },
                        );
                    }
                    LoginMessage::LoginSuccess(
                        result,
                    ) => {
                        self.console.info(&format!("LoginSuccess, employee: {:?}", result));
                        self.login_fetch = None;
                        self.current_employee =
                            match result {
                                Some(result) => result.employee.clone(),
                                None => None
                            };
                        let calendar_model =
                            CalendarModel {
                                mode: CalendarMode::NoModal,
                                view_mode:
                                    CalendarView::Day,
                            };
                        self.link.send_self(Message::FetchData);
                        self.link.send_self(
                            Message::SwitchPage(
                                Page::Calendar(
                                    calendar_model,
                                ),
                            ),
                        );
                    }
                    LoginMessage::LoginFail => {
                        self.console.info("LoginFail");
                        self.login_fetch = None;
                        self.page = Page::Login(
                            LoginModel::default(),
                        );
                    }
                }
            }
            (
                Page::Calendar(page),
                Message::Calendar(
                    CalendarMessage::OpenModal(mode),
                ),
            ) => {
                self.console.info(&format!("Open modal {:?}", mode));
                page.mode = mode.clone();
            }
            (
                Page::Calendar(page),
                Message::Calendar(
                    CalendarMessage::CloseModal,
                ),
            ) => {
                self.console.info("Close modal");
                page.mode = CalendarMode::NoModal;
            }
            (
                _, Message::FetchData
            ) => {
                self.console.info("Fetch data from server");
                self.employees_fetch = http_post(
                    &mut self.fetch_service,
                    &mut self.link,
                    "/sched/get_employees",
                    |res| {
                        Message::ReceiveEmployees(res)
                    },
                    || Message::NoOp,
                );
                self.configs_fetch = http_post(
                    &mut self.fetch_service,
                    &mut self.link,
                    "/sched/get_configs",
                    |res| {
                        Message::ReceiveConfigs(res)
                    },
                    || Message::NoOp,
                );
                self.active_config_fetch = http_post(
                    &mut self.fetch_service,
                    &mut self.link,
                    "/sched/get_active_config",
                    |res| {
                        Message::ReceiveActiveConfig(res)
                    },
                    || Message::NoOp,
                );
                self.shifts_fetch = http_post(
                    &mut self.fetch_service,
                    &mut self.link,
                    "/sched/get_shifts",
                    |res| {
                        Message::ReceiveShifts(res)
                    },
                    || Message::NoOp,
                );
                self.shifts_fetch = http_post(
                    &mut self.fetch_service,
                    &mut self.link,
                    "/sched/get_shifts",
                    |res| {
                        Message::ReceiveShifts(res)
                    },
                    || Message::NoOp,
                );
                self.shift_exceptions_fetch = http_post(
                    &mut self.fetch_service,
                    &mut self.link,
                    "/sched/get_shift_exceptions",
                    |res| {
                        Message::ReceiveShiftExceptions(res)
                    },
                    || Message::NoOp,
                );
                self.vacations_fetch = http_post(
                    &mut self.fetch_service,
                    &mut self.link,
                    "/sched/get_vacations",
                    |res| {
                        Message::ReceiveVacations(res)
                    },
                    || Message::NoOp,
                );
            }
            (_, Message::SwitchPage(page)) => {
                self.console.info(&format!("Switch page to {:?}", page));
                self.page = page.clone();
            }
            
            
            _ => (),
        };
        info(&format!("post-update model: {:?}", self));
        true
    }
}

impl Renderable<Model> for Model {
    fn view(&self) -> Html<Self> {
        info("model.view()");
        html! {
            <div>
            {
                match &self.page {
                    Page::CheckToken => {
                        html!{
                            <h1>{"Authenticating..."}</h1>
                        }
                    }
                    Page::Login(page) => {
                        self.view_login_page(page)
                    }
                    Page::Calendar(page) => {
                        self.view_calendar_page(page)
                    }
                }
            }
            </div>
        }
    }
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

pub fn main() {
    yew::start_app::<Model>();
}
