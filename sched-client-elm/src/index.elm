import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Url
import Json.Decode as D
import Json.Encode as E
import Login
import Calendar
import Settings

-- domain_url = "http://localhost/8000/sched"

-- MAIN
main : Program () Model Message
main =
  Browser.application
    {
      init=init,
      view=view,
      update=update,
      subscriptions=subscriptions,
      onUrlChange=UrlChanged,
      onUrlRequest=UrlRequest
    }

-- MODEL
type Page =
  Login Login.Model |
  Settings Settings.Model |
  Calendar Calendar.Model

type alias Model =
  {
    navkey : Nav.Key,
    page : Page
  }
init : () -> Page -> Nav.Key -> (Model, Cmd Message)
init flags page key =
  (Model key page, Cmd.none)

-- UPDATE
type Message =
  UrlChanged Url.Url |
  UrlRequest Browser.UrlRequest
  -- AddEmployee Name String |
  -- AddShift Employee DateTime Float

update : Message -> Model -> ( Model, Cmd Message )
update msg model =
  case msg of
    UrlRequest urlRequest ->
      case urlRequest of
        Browser.Internal url ->
          (model, Nav.pushUrl model.navkey (Url.toString url))
        Browser.External href ->
          (model, Cmd.none)
    UrlChanged url ->
      case url.path of
        "/sched/login" ->
      ({ model | url = url }, Cmd.none)

-- SUBSCRIPTIONS
subscriptions : Model -> Sub Message
subscriptions model =
    Sub.none

-- VIEW
view : Model -> Browser.Document Message
view model =
  {
    title = "Scheduler",
    body =
      [
        text "The current URL is: ",
        b [] [ text (Url.toString model.url) ],
        ul []
          [
            viewLink "/login",
            viewLink "/settings",
            viewLink "/calendar"
          ]
      ]
  }

viewLink : String -> Html msg
viewLink path =
  li [] [ a [ href path ] [ text path ] ]