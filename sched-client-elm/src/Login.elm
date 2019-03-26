module Login exposing (Model, Message(..), init, update, view)
import Browser
import Json.Decode as D
import Json.Encode as E
import Http
import Url.Builder as UB
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Session exposing (Session)
import Browser.Navigation as Nav

type InputState =
  Normal |
  Success |
  Danger |
  Disabled

type alias LoginInfo = 
  {
    email : String,
    password : String
  }

type alias Model =
  {
    session : Session,
    login_info : LoginInfo,
    email_state : InputState,
    password_state : InputState,
    button_state : InputState
  }

encode : LoginInfo -> E.Value
encode loginValue =
  E.object
    [
      ("email", E.string loginValue.email),
      ("password", E.string loginValue.password)
    ]

loginRequest : LoginInfo -> (Cmd Message)
loginRequest loginInfo =
  Http.post
    {
      url = UB.absolute ["sched", "login_request"][],
      body = Http.jsonBody (encode loginInfo),
      expect = Http.expectWhatever LoginResponse
    }

createUser : LoginInfo -> (Cmd Message)
createUser loginInfo =
  Http.post
    {
      url = UB.absolute ["sched", "create_user"][],
      body = Http.jsonBody (encode loginInfo),
      expect = Http.expectWhatever LoginResponse
    }

updateLoginButton : Model -> Model
updateLoginButton page =
  if page.email_state == Success && 
    page.password_state == Success
    then { page | button_state = Success }
    else { page | button_state = Normal }

type Message =
  CreateUser |
  LoginRequest |
  LoginResponse (Result Http.Error ()) |
  UpdateEmail String |
  UpdatePassword String

init : Session -> (Model, Cmd Message)
init session = 
  (Model session (LoginInfo "" "") Normal Normal Normal, Cmd.none)

update : Model -> Message -> (Model, Cmd Message)
update model msg =
  case msg of
    CreateUser ->
      (model, createUser model.login_info)
    LoginRequest ->
      (model, loginRequest model.login_info)
    LoginResponse r ->
      case r of
        Ok _ ->
          (model, 
            (Nav.pushUrl 
              model.session.navkey 
              (UB.absolute ["sched", "calendar"][])))
        Err _ ->
          ({ model | login_info = LoginInfo "" "" }, Cmd.none)
    UpdateEmail email ->
      ({ model | login_info = 
        LoginInfo email model.login_info.password }, Cmd.none)
    UpdatePassword password ->
      ({ model | login_info =
        LoginInfo model.login_info.email password }, Cmd.none)

view : Model -> List (Html Message)
view model =
  [
    h1 [][text "Login to Scheduler"],
    Html.form 
      [
        onSubmit LoginRequest
      ]
      [
        div [][
          label [][text "Email"],
          input 
            [
              onInput UpdateEmail,
              type_ "email", 
              placeholder "you@something.com"
            ][]
        ],
        div [][
          label [][text "Password"],
          input 
            [
              onInput UpdatePassword,
              type_ "password",
              placeholder "Password"][]
        ],
        button [][text "Login"],
        button [onClick CreateUser][text "Create User"]
      ],
    a [href "/sched/calendar"][text "calendar"],
    div [][],
    a [href "/sched/settings"][text "settings"]
  ]
