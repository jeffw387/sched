module Employee exposing (..)
import Json.Decode.Pipeline as JPipe
import Json.Decode as D
import Json.Encode as E
import Dict exposing (Dict)
import Shift exposing (Shift)

type alias Name =
  {
    first : String,
    last : String
  }

type alias Employee = 
  {
    id : Int,
    name : Name,
    phone_number : Maybe String
  }

type alias EmployeesData =
  {
    employees : List Employee,
    employeeShifts : Dict Int (List Shift)
  }

dataDefault = EmployeesData [] Dict.empty

toString : Name -> String
toString name =
  name.first ++ " " ++ name.last

nameDecoder : D.Decoder Name
nameDecoder =
  D.succeed Name
  |> JPipe.required "first" D.string
  |> JPipe.required "last" D.string

nameEncoder : Name -> E.Value
nameEncoder n =
  E.object 
    [
      ("first", E.string n.first),
      ("last", E.string n.last)
    ]

employeeDecoder : D.Decoder Employee
employeeDecoder =
  D.succeed Employee
  |> JPipe.required "id" D.int
  |> JPipe.requiredAt ["name"] nameDecoder
  |> JPipe.required "phone_number" (D.maybe D.string)

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