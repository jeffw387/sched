module Calendar exposing (Model, init, update, view)
import Time exposing (Posix)
import Dict exposing (Dict)
import Http
import Url
import Url.Builder as UB
import Json.Decode as D
import Json.Encode as E

type alias DateTime = Time.Posix

type ViewType =
  Month |
  Week |
  Day

type alias Name =
  {
    first : String,
    last : String
  }

type alias Employee = 
  {
    id : Int,
    name : Name,
    phone_number : String
  }

type alias ShiftTime =
  {
    year : Int,
    month : Int,
    day : Int,
    hour : Int,
    minute : Int
  }

type alias ShiftDuration =
  {
    hours: Int,
    minutes: Int
  }

type alias Shift =
  {
    id : Int,
    employee_id : Int,
    start : ShiftTime,
    duration : ShiftDuration
  }

shiftDecode : D.Decoder Shift
shiftDecode =
  D.map4
    (D.field "id" D.int)
    (D.field "employee_id" D.int)
    (D.field "start" D.int)

type alias Model = 
  {
    employees : List Employee,
    employeeShifts : Dict Employee Shift
  }

nameDecoder : D.Decoder Name
nameDecoder =
  D.map2
    (D.field "first" D.string)
    (D.field "last" D.string)

employeeDecoder : D.Decoder Employee
employeeDecoder =
  D.map3 Employee
    (D.field "id" D.int)
    nameDecoder
    (D.field "phone_number" D.string)

init : (Model, Cmd Message)
init =
  (update Model RequestEmployees)

type Message = 
  RequestEmployees |
  RequestShifts Employee |
  ReceiveEmployees (List Employee) |
  ReceiveShifts Employee (List Shift)

update : Model -> Message -> (Model, (Cmd msg))
update model msg =
  case msg of
    RequestEmployees ->
      (model,
        Http.post {
        url=UB.absolute ["sched", "get_employees"] [],
        body=Http.emptyBody,
        expect=Http.expectJson D.list })
    RequestShifts ->