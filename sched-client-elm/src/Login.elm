module Login exposing (Model, Message(..), init, update, view)
import Browser
import Json.Decode as D
import Json.Encode as E
import Http
import Url.Builder as UB
-- import Html exposing (..)
-- import Html.Attributes exposing (..)
-- import Html.Events exposing (..)
import Element exposing (Element)
import Element.Input as Input
import Element.Background as BG
import Element.Border as Border
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

elementShadow =
  Border.shadow
    {
      offset = (4, 4),
      size = 3,
      blur = 10,
      color = Element.rgba 0 0 0 0.5
    }

view : Model -> Element Message
view model =
  Element.column 
    [
      Element.padding 100, 
      Element.width Element.fill,
      BG.color (Element.rgb 0.6 0.8 0.9),
      Element.centerY
    ] 
    [
      Element.column 
        [
          Element.centerX
        ]
        [
          Element.el 
            [
              Element.centerX,
              Element.padding 15
            ] (Element.text "Login to Scheduler"),
          Element.column
            [
              Element.spacing 15
            ]
            [
              Input.username
                [
                  Element.alignRight,
                  Input.focusedOnLoad,
                  Element.width (Element.px 300),
                  -- elementShadow,
                  Element.padding 15,
                  Element.spacing 15
                ]
                {
                  label = Input.labelLeft [] (Element.text "Email"),
                  onChange = UpdateEmail,
                  placeholder = Just (Input.placeholder [] (Element.text "you@something.com")),
                  text = model.login_info.email
                },
              Input.currentPassword
                [
                  Element.alignRight,
                  Element.width (Element.px 300),
                  -- elementShadow,
                  Element.padding 15,
                  Element.spacing 15
                ]
                {
                  onChange = UpdatePassword,
                  text = model.login_info.password,
                  label = Input.labelLeft [] (Element.text "Password"),
                  placeholder = Just (Input.placeholder [] (Element.text "Password")),
                  show = False
                }
            ],
          Element.row
            [
              Element.alignRight,
              Element.width (Element.px 300),
              Element.paddingXY 0 15
            ]
            [
              Input.button 
                [ 
                  Element.alignLeft,
                  BG.color (Element.rgb 0.25 0.8 0.25),
                  elementShadow,
                  Element.padding 10
                ]
                {
                  label = Element.text "Login",
                  onPress = Just LoginRequest
                },
              Input.button 
                [ 
                  Element.alignRight,
                  BG.color (Element.rgb 0.45 0.45 0.8),
                  elementShadow,
                  Element.padding 10
                ]
                {
                  label = Element.text "Create User",
                  onPress = Just CreateUser
                }
            ]
        ]
    ]
