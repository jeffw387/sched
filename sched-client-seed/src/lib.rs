use seed::dom_types::{
    Attrs,
    Ev,
};
use seed::prelude::*;
use seed::{
    attrs,
    // log,
    button,
    div,
    form,
    input,
    label,
};

use sched::employee::{Employee, Name};
use sched::shift::Shift;

use sched::message::LoginInfo;

use chrono::NaiveDateTime;

#[derive(Clone, Debug)]
struct LoginPage {
    login_info: LoginInfo,
    email_state: InputState,
    password_state: InputState,
    button_state: InputState,
}

impl Default for LoginPage {
    fn default() -> Self {
        LoginPage {
            login_info: LoginInfo::default(),
            email_state: InputState::Normal,
            password_state: InputState::Normal,
            button_state: InputState::Disabled,
        }
    }
}

enum ViewType {
    Month,
    Week,
    Day,
}

#[derive(Clone, Debug)]
struct SettingsPage {}

#[derive(Clone, Debug)]
struct CalendarPage {
    employees: Vec<Employee>,
    employee_shifts: HashMap<Employee, Shift>,
}

#[derive(Clone, Debug)]
enum ModelPages {
    Login(LoginPage),
    Settings(SettingsPage),
    Calendar(CalendarPage),
}

impl Default for ModelPages {
    fn default() -> Self {
        ModelPages::Login(LoginPage::default())
    }
}

#[derive(Debug)]
struct Model {
    page: ModelPages,
}

impl Default for Model {
    fn default() -> Self {
        Model { page: ModelPages::default() }
    }
}

#[derive(Clone, Debug)]
enum Message {
    Page(ModelPages),
    Login(LoginInfo),
    UpdateEmail(String),
    UpdatePassword(String),
    AddEmployee(Name, String),
    AddShift(Employee, NaiveDateTime, f32)
}

fn validate_email(email: &str) -> InputState {
    use InputState::*;
    if email.len() == 0 {
        return Normal;
    };
    let at_pieces: Vec<&str> = email.split('@').collect();
    match at_pieces.len() {
        2 => {
            let user = at_pieces[0];
            if user.len() == 0 {
                return Danger;
            };
            let domain = at_pieces[1];
            if domain.len() == 0 {
                return Danger;
            };
            let dot_pieces: Vec<&str> =
                domain.split('.').collect();
            match dot_pieces.len() {
                2 => {
                    if dot_pieces[1].len() > 0 {
                        Success
                    } else {
                        Danger
                    }
                }
                _ => Danger,
            }
        }
        _ => Danger,
    }
}

fn update_login_button(page: &mut LoginPage) {
    if page.email_state == InputState::Success
        && page.password_state == InputState::Success
    {
        page.button_state = InputState::Success;
    }
}

fn update(
    msg: Message,
    model: &mut Model,
) -> Update<Message> {
    match &msg {
        Message::Page(new_page) => {
            model.page = new_page.clone() as ModelPages;
        }
        Message::Login(_info) => {
            if let ModelPages::Login(page) = &mut model.page
            {
                page.button_state = InputState::Disabled;
                page.email_state = InputState::Disabled;
                page.password_state = InputState::Disabled;
            };
            ()
        }
        Message::UpdateEmail(email) => {
            if let ModelPages::Login(page) = &mut model.page
            {
                page.login_info.email = email.clone();
                page.email_state = validate_email(&email);
                update_login_button(page);
            };
        }
        Message::UpdatePassword(password) => {
            if let ModelPages::Login(page) = &mut model.page
            {
                page.login_info.password = password.clone();
                page.password_state =
                    match password.len().cmp(&0) {
                        std::cmp::Ordering::Greater => {
                            InputState::Success
                        }
                        _ => InputState::Normal,
                    };
                update_login_button(page);
            };
        },
        Message::AddEmployee(name, phone_number) => {},
        Message::AddShift(employee, start, duration_hours) => {}
    };
    Render.into()
}

#[derive(Clone, Debug, Copy, PartialEq)]
enum InputState {
    Normal,
    Success,
    Danger,
    Disabled,
}

impl Default for InputState {
    fn default() -> Self {
        InputState::Normal
    }
}

fn input_attrs(state: InputState) -> Attrs {
    let mut res = Attrs::empty();
    let mut classes =
        vec!["uk-input", "uk-form-width-medium"];
    match state {
        InputState::Normal => (),
        InputState::Success => {
            classes.push("uk-form-success")
        }
        InputState::Danger => {
            classes.push("uk-form-danger")
        }
        InputState::Disabled => {
            res.add(At::Disabled, "true")
        }
    }
    res.add_multiple(At::Class, classes);
    res
}

fn button_attrs(state: InputState) -> Attrs {
    let mut res = Attrs::empty();
    let mut classes = vec!["uk-input"];
    match state {
        InputState::Normal => (),
        InputState::Success => {
            classes.push("uk-form-success")
        }
        InputState::Danger => {
            classes.push("uk-form-danger")
        }
        InputState::Disabled => {
            res.add(At::Disabled, "true")
        }
    }
    res.add_multiple(At::Class, classes);
    res
}

fn view(model: &Model) -> El<Message> {
    match &model.page {
        ModelPages::Login(login_page) => {
            div![form![
                attrs! {
                At::Class => "uk-position-top-center";
                At::Class => "uk-position-medium";
                // At::Class => "uk-form-horizontal";
                },
                div![
                    label![
                        "Email:",
                        attrs! {At::Class => "uk-form-label"}
                    ],
                    input![
                        attrs! {
                            At::Type => "email";
                            At::Class => "uk-align-center";
                            At::Value => login_page.login_info.email;
                        }
                        .merge(&input_attrs(
                            login_page
                            .email_state
                        )),
                        input_ev(
                            Ev::Input,
                            Message::UpdateEmail
                        )
                        ]
                ],
                div![
                    label![
                        "Password:",
                        attrs! {At::Class => "uk-form-label"}
                    ],
                    input![
                    attrs! {
                        At::Type => "password";
                        At::Class => "uk-align-center";
                        At::Value => login_page.login_info.password;
                    }
                    .merge(&input_attrs(
                        login_page
                        .password_state
                    )),
                    input_ev(
                        Ev::Input,
                        Message::UpdatePassword
                    )
                    ]
                ],
                button![button_attrs(login_page.button_state), "Login"]
            ],]
        }
        ModelPages::Settings(_settings_page) => {
            div![
                attrs![At::Class => "SettingsPage"],
                "Placeholder for settings page."
            ]
        }
        ModelPages::Calendar(_calendar_page) => {
            div![
                attrs![At::Class => "CalendarPage"],
                "Placeholder for calendar page."
            ]
        }
    }
}

#[wasm_bindgen]
pub fn render() {
    std::panic::set_hook(Box::new(
        console_error_panic_hook::hook,
    ));
    seed::App::build(Model::default(), update, view)
        .finish()
        .run();
}
