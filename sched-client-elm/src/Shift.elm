module Shift exposing (Shift, decoder)
import Json.Decode.Pipeline as JPipe
import Json.Decode as D
import Json.Encode as E

type alias Shift =
  {
    id : Int,
    employee_id : Int,
    year : Int,
    month : Int,
    day : Int,
    hour : Int,
    minute : Int,
    hours : Int,
    minutes : Int
  }

decoder : D.Decoder Shift
decoder =
  D.succeed Shift
    |> JPipe.required "id" D.int
    |> JPipe.required "employee_id" D.int
    |> JPipe.required "year" D.int
    |> JPipe.required "month" D.int
    |> JPipe.required "day" D.int
    |> JPipe.required "hour" D.int
    |> JPipe.required "minute" D.int
    |> JPipe.required "hours" D.int
    |> JPipe.required "minutes" D.int