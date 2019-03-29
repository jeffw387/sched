module Calendar exposing (Model, Message(..), init, update, view, toSession)
import Time exposing (Posix)
import Dict exposing (Dict)
import Json.Decode.Pipeline as JPipe
import Json.Decode as D
import Json.Encode as E
import Html exposing (..)
import Html.Attributes exposing (..)
import Session exposing (Session)
import Employee exposing (..)
import Shift exposing (..)
import Http
import Url
import Api
import Browser
import Month
import Week
import Day
import Query
import CalendarLoad
import Element

type Model =
  CalendarLoadModel CalendarLoad.Model |
  MonthModel Month.Model |
  WeekModel Week.Model |
  DayModel Day.Model

toParentTypes : (CalendarLoad.Model, Cmd CalendarLoad.Message) 
  -> (Model, Cmd Message)
toParentTypes (model, cmdMsg) =
  (CalendarLoadModel model, Cmd.map LoadingMsg cmdMsg)

init : Session -> (Model, Cmd Message)
init session =
  toParentTypes (CalendarLoad.init session)

type Message = 
  LoadingMsg CalendarLoad.Message |
  MonthMsg Month.Message |
  WeekMsg Week.Message |
  DayMsg Day.Message

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

viewSwitch : Session.ViewType -> Model -> Model
viewSwitch viewType model =
  case viewType of
    Session.Month ->
      case model of
        CalendarLoadModel loadModel ->
          MonthModel 
            (Month.Model 
            loadModel.session 
            loadModel.employeesData 
            Nothing)
        MonthModel monthModel -> model
        WeekModel weekModel ->
          MonthModel 
            (Month.Model
            weekModel.session
            weekModel.employeesData
            Nothing)
        DayModel dayModel ->
          MonthModel 
            (Month.Model
            dayModel.session
            dayModel.employeesData
            Nothing)
    Session.Week ->
      case model of
        CalendarLoadModel loadModel ->
          WeekModel 
            (Week.Model 
            loadModel.session 
            loadModel.employeesData 
            Nothing)
        MonthModel monthModel ->
          WeekModel 
            (Week.Model
            monthModel.session
            monthModel.employeesData
            Nothing)
        WeekModel weekModel -> model
        DayModel dayModel ->
          WeekModel 
            (Week.Model
            dayModel.session
            dayModel.employeesData
            Nothing)
    Session.Day ->
      case model of
        CalendarLoadModel loadModel ->
          DayModel 
            (Day.Model 
            loadModel.session 
            loadModel.employeesData 
            Nothing)
        MonthModel monthModel ->
          DayModel 
            (Day.Model
            monthModel.session
            monthModel.employeesData
            Nothing)
        WeekModel weekModel ->
          DayModel
            (Day.Model
            weekModel.session
            weekModel.employeesData
            Nothing)
        DayModel dayModel -> model

update : Model -> Message -> (Model, Cmd Message)
update model msg =
  case (model, Debug.log "Calendar Message" msg) of
    (CalendarLoadModel loadModel, LoadingMsg loadMsg) ->
      case loadMsg of
        CalendarLoad.DoneLoading -> 
          (viewSwitch loadModel.session.settings.viewType model,
          Cmd.none)
        _ -> CalendarLoad.update loadModel loadMsg
          |> updateWith CalendarLoadModel LoadingMsg model
    (MonthModel monthModel, MonthMsg monthMessage) ->
      Month.update monthModel monthMessage
      |> updateWith MonthModel MonthMsg model
    (WeekModel weekModel, WeekMsg weekMessage) ->
      Week.update weekModel weekMessage
      |> updateWith WeekModel WeekMsg model
    (DayModel dayModel, DayMsg dayMessage) ->
      Day.update dayModel dayMessage
      |> updateWith DayModel DayMsg model
    (_, _) -> (model, Cmd.none)

toSession : Model -> Session
toSession model =
  case model of
    CalendarLoadModel loadModel -> loadModel.session
    MonthModel monthModel -> monthModel.session
    WeekModel weekModel -> weekModel.session
    DayModel dayModel -> dayModel.session

view model = 
  case model of
    CalendarLoadModel loadModel -> Element.text "Loading..."
    MonthModel monthModel ->
      Month.view 
        monthModel
      |> Element.map MonthMsg
    WeekModel weekModel -> Element.none
    DayModel dayModel -> Element.none
