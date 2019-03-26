module Calendar exposing (Model, Message(..), init, update, view)
import Time exposing (Posix)
import Dict exposing (Dict)
import Http
import Url
import Api
import Json.Decode.Pipeline as JPipe
import Json.Decode as D
import Json.Encode as E
import Html exposing (..)
import Html.Attributes exposing (..)
import Session exposing (Session)
import Browser
import Employee exposing (..)
import Shift exposing (..)
import Month

type alias Model = 
  {
    session : Session,
    employees : List Employee,
    employeeShifts : Dict Int (List Shift)
  }

type alias EmployeesQuery =
  {
    employees : List Employee
  }

employeesQueryDecoder : D.Decoder EmployeesQuery
employeesQueryDecoder =
  D.succeed EmployeesQuery
  |> JPipe.requiredAt ["employees"] (D.list employeeDecoder)

type alias ShiftsQuery =
  {
    shifts : List Shift
  }

shiftsQueryDecoder : D.Decoder ShiftsQuery
shiftsQueryDecoder =
  D.succeed ShiftsQuery
  |> JPipe.requiredAt ["shifts"] (D.list Shift.decoder)

employeeEncoder : Employee -> E.Value
employeeEncoder e =
  E.object
    [
      ("id", E.int e.id),
      ("name", nameEncoder e.name),
      case e.phone_number of
        Just pn -> ("phone_number", E.string pn)
        Nothing -> ("phone_number", E.null)
    ]

init : Session -> (Model, Cmd Message)
init session =
  (Model session [] Dict.empty, requestEmployees)

type Message = 
  ReceiveEmployees (Result Http.Error (EmployeesQuery)) |
  ReceiveShifts Employee (Result Http.Error (ShiftsQuery))

requestEmployees : Cmd Message
requestEmployees =
  Http.post 
  {
    url=Api.getEmployees,
    body=Http.emptyBody,
    expect=Http.expectJson ReceiveEmployees employeesQueryDecoder
  }

requestShifts : Employee -> Cmd Message
requestShifts emp =
  Debug.log ("Requesting shifts for employee" ++ (Debug.toString emp))
  Http.post {
    url=Api.getShifts,
    body=Http.jsonBody (employeeEncoder emp),
    expect=Http.expectJson (ReceiveShifts emp) shiftsQueryDecoder
  }

update : Model -> Message -> (Model, Cmd Message)
update model msg =
  case msg of
    ReceiveEmployees employeesResult ->
      case employeesResult of
        Ok employees ->
          ({ model | employees = employees.employees }, 
            Cmd.batch (List.map requestShifts employees.employees))
        Err e ->
          (model, Cmd.none)
          
    ReceiveShifts employee shiftsResult ->
      case shiftsResult of
        Ok shifts ->
          ({ model | employeeShifts = Dict.insert employee.id shifts.shifts model.employeeShifts}, Cmd.none)
        Err e ->
          (model, Cmd.none)

view : Model -> List (Html Message)
view model = 
  case model.session.settings.viewType of
    Session.Month -> 
      Month.view 
        model.session 
        model.employees 
        model.employeeShifts
    Session.Week -> []
    Session.Day -> []