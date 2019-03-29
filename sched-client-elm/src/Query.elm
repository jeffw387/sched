module Query exposing (..)

import Shift exposing (Shift)
import Employee exposing (Employee, employeeDecoder)
import Json.Decode.Pipeline as JPipe
import Json.Decode as D
import Json.Encode as E

type alias Employees =
  {
    employees : List Employee
  }

employeesQueryDecoder : D.Decoder Employees
employeesQueryDecoder =
  D.succeed Employees
  |> JPipe.requiredAt ["employees"] (D.list employeeDecoder)

type alias Shifts =
  {
    shifts : List Shift
  }

shiftsQueryDecoder : D.Decoder Shifts
shiftsQueryDecoder =
  D.succeed Shifts
  |> JPipe.requiredAt ["shifts"] (D.list Shift.decoder)