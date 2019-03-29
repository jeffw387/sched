module Day exposing (..)
import Session exposing (Session)
import Employee exposing (Employee, EmployeesData)
import Shift exposing (Shift)
import Dict exposing (Dict)

type alias HoverData =
  {

  }

type alias Model =
  {
    session : Session,
    employeesData : EmployeesData,
    hover : Maybe HoverData
  }

type Message = None

update model msg = (model, Cmd.none)

view model = []