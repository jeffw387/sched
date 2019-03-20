module Settings exposing (Model, init, update, view)
import Html exposing (..)
import Html.Attributes exposing (..)

type alias Model = {}

init : Model
init =
  Model

type Message = None

update : Model -> Message -> (Model, Cmd Message)
update model message =
  (model, Cmd.none)

view : Model -> Html msg
view model =
  div [] [ text "Settings Page" ]