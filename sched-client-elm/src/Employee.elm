module Employee exposing (..)
import Json.Decode.Pipeline as JPipe
import Json.Decode as D
import Json.Encode as E

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