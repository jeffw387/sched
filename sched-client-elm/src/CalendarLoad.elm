module CalendarLoad exposing (..)
import Session exposing (Session)
import Employee exposing (..)
import Dict exposing (Dict)
import Http
import Query
import Api
import Task

type alias Model =
  {
    session : Session,
    employeesData : EmployeesData,
    loaded : Dict Int Bool
  }

type Message =
  ReceiveEmployees (Result Http.Error (Query.Employees)) |
  ReceiveShifts Employee (Result Http.Error (Query.Shifts)) |
  DoneLoading

update : Model -> Message -> (Model, Cmd Message)
update model message =
  case message of
    ReceiveEmployees employeesResult ->
      case employeesResult of
        Ok employees ->
          let 
            loadingModel = setLoadTasks employees.employees model
          in
            ({ loadingModel | employeesData = 
              EmployeesData 
              employees.employees 
              Dict.empty }, 
            Cmd.batch (List.map requestShifts employees.employees))
        Err e ->
          (model, Cmd.none)
    ReceiveShifts employee shiftsResult ->
      case shiftsResult of
        Ok shifts ->
          let
            markedModel = markTaskComplete employee.id model
          in
              
            if tasksComplete markedModel then
              ({ markedModel | employeesData = 
                EmployeesData
                  model.employeesData.employees
                  (Dict.insert 
                    employee.id
                    shifts.shifts
                    model.employeesData.employeeShifts)}, 
                  Task.succeed DoneLoading 
                  |> Task.perform identity)
            else
              ({ markedModel | employeesData = 
                EmployeesData
                  model.employeesData.employees
                  (Dict.insert 
                    employee.id
                    shifts.shifts
                    model.employeesData.employeeShifts)}, Cmd.none)
        Err e -> 
          -- (Debug.log "receive shifts error" e)
          (model, Cmd.none)
    DoneLoading -> (model, Cmd.none)

tasksComplete : Model -> Bool
tasksComplete model =
  Dict.foldl (\k v b -> 
    case b of
      True ->
        case v of
          False -> False
          True -> True
      False -> False) True model.loaded

foldEmployeesIntoTasks : Employee -> Dict Int Bool -> Dict Int Bool
foldEmployeesIntoTasks employee inDict =
  Dict.insert employee.id False inDict

markTaskComplete : Int -> Model -> Model
markTaskComplete id model =
  { model | loaded = Dict.insert id True model.loaded }

setLoadTasks : List Employee -> Model -> Model
setLoadTasks employees model =
  let 
    loaded = List.foldl foldEmployeesIntoTasks Dict.empty employees
  in
    Model model.session model.employeesData loaded

requestEmployees : Cmd Message
requestEmployees =
  Http.post 
  {
    url=Api.getEmployees,
    body=Http.emptyBody,
    expect=Http.expectJson ReceiveEmployees Query.employeesQueryDecoder
  }

requestShifts : Employee -> Cmd Message
requestShifts emp =
  Debug.log ("Requesting shifts for employee" ++ (Debug.toString emp))
  Http.post {
    url=Api.getShifts,
    body=Http.jsonBody (employeeEncoder emp),
    expect=Http.expectJson (ReceiveShifts emp) Query.shiftsQueryDecoder
  }

init : Session -> (Model, Cmd Message)
init session =
    (Model 
      session 
      Employee.dataDefault 
      Dict.empty,
    requestEmployees)