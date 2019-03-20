module Login exposing (Model, init, update, view)
import Browser
import Json.Decode as D
import Json.Encode as E
import Http

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
      url = "/login_request",
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
  LoginRequest |
  LoginResponse (Result Http.Error ()) |
  UpdateEmail String |
  UpdatePassword String
