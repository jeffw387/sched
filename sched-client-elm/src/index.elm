import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Url
import Api
import Json.Decode as D
import Json.Encode as E
import Login
import Calendar
import Task
import Session exposing (Session)

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
type Model =
  LoginPage Login.Model |
  CalendarPage Calendar.Model


init : () -> Url.Url -> Nav.Key -> (Model, Cmd Message)
init _ url key =
  Session url key (Session.Settings Session.Month Session.Hour12)
    |> Login.init 
    >> \(lmdl, lmsg) -> (LoginPage lmdl, Cmd.map LoginMsg lmsg)

-- UPDATE
type Message =
  UrlChanged Url.Url |
  UrlRequest Browser.UrlRequest |
  LoginMsg Login.Message |
  CalendarMsg Calendar.Message

updateWith : (subModel -> Model) -> 
  (subMessage -> Message) -> 
  Model -> 
  (subModel, Cmd subMessage) -> 
  (Model, Cmd Message)
updateWith toModel toMessage model (subModel, subCmd) =
  ( 
    toModel subModel,
    Cmd.map toMessage subCmd
  )

toSession : Model -> Session
toSession model =
  case model of
    LoginPage page ->
      page.session
    CalendarPage page ->
      page.session

index model url =
  Debug.log (Debug.toString url)
  toSession model 
  |> Login.init 
  |> \(a, b) -> (LoginPage a, Cmd.map LoginMsg b)

update : Message -> Model -> (Model, Cmd Message)
update msg model =
  case (msg, model) of
    (UrlRequest urlRequest, page) ->
      case urlRequest of
        Browser.Internal url ->
          Debug.log "Internal browser url request"
          (model, Nav.pushUrl (toSession page).navkey (Url.toString url))
        Browser.External href ->
          Debug.log "External browser url request"
          (model, Cmd.none)
    (UrlChanged url, _) ->
      case url.path of
        "/sched" ->
          Debug.log("Url changed to " ++ (Url.toString url))
          index model url
        "/sched/login" ->
          Debug.log("Url changed to " ++ (Url.toString url))
          index model url
        "/sched/calendar" ->
          Debug.log("Url changed to " ++ (Url.toString url))
          toSession model
          |> Calendar.init
          |> \(a, b) -> (CalendarPage a, Cmd.map CalendarMsg b)
        _ -> 
          Debug.log "Url changed, no match"
          (model, Cmd.none)
    (LoginMsg loginMsg, LoginPage loginPage) ->
      Debug.log ("LoginMsg: " ++ (Debug.toString loginMsg))
      Login.update loginPage loginMsg
        |> updateWith LoginPage LoginMsg model
    (CalendarMsg calMsg, CalendarPage calPage) ->
      Debug.log ("CalendarMsg: " ++ (Debug.toString calMsg))
      Calendar.update calPage calMsg
        |> updateWith CalendarPage CalendarMsg model
    (_, _) -> 
      Debug.log "Unknown message"
      (model, Cmd.none)

-- SUBSCRIPTIONS
subscriptions : Model -> Sub Message
subscriptions model =
    Sub.none

toDocument : (List (Html Message)) -> (Browser.Document Message)
toDocument htmlList =
  {
    title = "Scheduler",
    body = htmlList
  }

-- VIEW
view : Model -> Browser.Document Message
view model =
  case model of
    LoginPage loginModel ->
      Login.view loginModel 
      |> List.map (Html.map LoginMsg) 
      |> toDocument
    CalendarPage calendarModel ->
      Calendar.view calendarModel 
      |> List.map (Html.map CalendarMsg) 
      |> toDocument

viewLink : String -> Html msg
viewLink path =
  li [] [ a [ href path ] [ text path ] ]