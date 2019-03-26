module Month exposing (view)
import Employee exposing (Employee)
import Shift exposing (Shift)
import Dict exposing (Dict)
import Session exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)

swapFirst : Employee -> (Int, List Shift) -> (Employee, List Shift)
swapFirst c (a, b) =
  (c, b)

mapEmployeeShifts : Dict Int (List Shift) -> List Employee -> List (Employee, List Shift)
mapEmployeeShifts shiftDict employees =
  List.map2 swapFirst employees (Dict.toList shiftDict)

matchDay : Day -> Shift -> Bool
matchDay day shift =
  shift.year == day.year && shift.month == day.month && shift.day == day.day

filterByDay : Day -> 
  (Employee, List Shift) -> (Employee, List Shift)
filterByDay day (employee, shifts) =
    (employee, List.filter (matchDay day) shifts)

mapShiftsToDay : Day -> 
  List (Employee, List Shift) -> List (Employee, List Shift)
mapShiftsToDay day employeeShifts =
  List.map (filterByDay day) employeeShifts

endsFromStartDur : (Int, Int) -> (Int, Int)
endsFromStartDur (start, duration) =
  (start, start + duration)

formatHour12 : Int -> String
formatHour12 rawHour =
  let 
    hour24 = modBy 24 rawHour
    hour12 = modBy 12 rawHour
  in 
  if hour24 > 12 then
        (String.fromInt hour12) ++ "p"
      else
        (String.fromInt hour12) ++ "a"

formatHour24 : Int -> String
formatHour24 rawHour =
  let 
    hour24 = modBy 24 rawHour
  in String.fromInt hour24

formatHours : Settings -> Int -> Int -> Html msg
formatHours settings start duration =
  case settings.hourFormat of
    Session.Hour12 -> 
      let (_, end) = endsFromStartDur (start, duration)
      in (text (formatHour12 start ++ "-" ++ formatHour12 end))
    Session.Hour24 -> 
      let (_, end) = endsFromStartDur (start, duration)
      in (text (formatHour24 start ++ "-" ++ formatHour24 end))

viewShift : Settings -> Shift -> Html msg
viewShift settings shift =
  div [] 
    [ 
      (formatHours settings shift.hour shift.hours)
    ]

viewEmployeeShifts : Settings -> 
  (Employee, List Shift) -> Html msg
viewEmployeeShifts settings (employee, shifts) =
  div [] (List.append 
    [text (Employee.toString employee.name)]
    (List.map (viewShift settings) shifts))

viewDay : Settings -> Day -> List (Employee, List Shift) -> Html msg
viewDay settings day employeeShifts =
  div [ class "uk-card", class "uk-card-default", class "uk-card-body" ]
    (List.append 
      [text (String.fromInt day.day)]
      (List.map (viewEmployeeShifts settings)
        (mapShiftsToDay day employeeShifts)))

gridAttr : Attribute msg
gridAttr =
  attribute "uk-grid" ""

viewRow : List (Maybe Day) -> Html msg
viewRow rowIndex =
  div [][]

type alias Day =
  {
    year : Int,
    month : Int,
    day : Int
  }

view : Session -> List Employee -> Dict Int (List Shift) -> List (Html msg)
view session employees shiftDict =
  Debug.log "Month view"
  [
    div [gridAttr, class "uk-child-width-expand@s", class "uk-text-center"]
    [
      viewDay session.settings (Day 2019 3 23)
        (mapEmployeeShifts shiftDict employees),
      viewDay session.settings (Day 2019 3 24) 
        (mapEmployeeShifts shiftDict employees)
    ]
  ]