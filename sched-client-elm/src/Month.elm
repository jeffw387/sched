module Month exposing (..)
import Employee exposing (Employee, EmployeesData)
import Shift exposing (Shift)
import Dict exposing (Dict)
import Session exposing (..)
-- import Html exposing (..)
-- import Html.Attributes exposing (..)
-- import Html.Events exposing (..)
import CalendarExtra exposing (..)
import Array exposing (Array)
import Http
import Query exposing (..)
import Element exposing (Element)
import Element.Background as BG
import Element.Input as Input
import Element.Border as Border
import Element.Font as Font

type Message =
  OverShift (Employee, Shift) |
  LeaveShift |
  ReceiveEmployees (Result Http.Error (Query.Employees)) |
  ReceiveShifts Employee (Result Http.Error (Query.Shifts))

type alias HoverData =
  {

  }

type alias Model =
  {
    session : Session,
    employeesData : EmployeesData,
    hover : Maybe HoverData
  }

swapFirst : Employee -> (Int, List Shift) -> (Employee, List Shift)
swapFirst c (a, b) =
  (c, b)

mapEmployeeShifts : Dict Int (List Shift) -> List Employee -> List (Employee, List Shift)
mapEmployeeShifts shiftDict employees =
  List.map2 swapFirst employees (Dict.toList shiftDict)

matchYearMonthDay : YearMonthDay -> Shift -> Bool
matchYearMonthDay day shift =
  shift.year == day.year && shift.month == day.month && shift.day == day.day

filterByYearMonthDay : YearMonthDay -> 
  (Employee, List Shift) -> (Employee, List Shift)
filterByYearMonthDay day (employee, shifts) =
    (employee, List.filter (matchYearMonthDay day) shifts)

mapShiftsToYearMonthDay : YearMonthDay -> 
  List (Employee, List Shift) -> List (Employee, List Shift)
mapShiftsToYearMonthDay day employeeShifts =
  List.map (filterByYearMonthDay day) employeeShifts

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

formatHours : Settings -> Int -> Int -> Element msg
formatHours settings start duration =
  case settings.hourFormat of
    Session.Hour12 -> 
      let (_, end) = endsFromStartDur (start, duration)
      in (Element.text (formatHour12 start ++ "-" ++ formatHour12 end))
    Session.Hour24 -> 
      let (_, end) = endsFromStartDur (start, duration)
      in (Element.text (formatHour24 start ++ "-" ++ formatHour24 end))


type alias Row =
  Array (Maybe YearMonthDay)

rowDefault : Row
rowDefault =
  Array.repeat 7 Nothing

type alias Month =
    Array Row

type alias RowID =
  {
    index : Int,
    maybeRow : Maybe Row
  }

type alias DayID =
  {
    index : Int,
    maybeDay : Maybe YearMonthDay
  }

monthDefault : Month    
monthDefault =
  Array.repeat 6 rowDefault

makeDaysForMonth : YearMonth -> Array YearMonthDay
makeDaysForMonth ym =
  List.range 1 (daysInMonth ym) 
      |> List.map (\d -> (withDay ym d))
      |> Array.fromList

foldAllEmpty : Maybe YearMonthDay -> Bool -> Bool
foldAllEmpty maybeYMD emptySoFar =
  case emptySoFar of
    True ->
      case maybeYMD of
        Just _ -> False
        Nothing -> True
    False -> False

allEmpty : Array (Maybe YearMonthDay) -> Bool
allEmpty ymdArray =
  Array.foldl foldAllEmpty True ymdArray

foldRowSelect : Int -> Row -> (RowID, DayID) -> (RowID, DayID)
foldRowSelect targetIndex row (rowID, dayID) =
    case allEmpty (Array.slice targetIndex 7 row) of
      True ->
          case rowID.maybeRow of
            Just alreadyFound -> (rowID, dayID)
            Nothing ->
              (RowID rowID.index (Just row), DayID targetIndex Nothing)
      False ->
          (RowID (rowID.index + 1) Nothing, dayID)

defaultID = (RowID 0 Nothing, DayID 0 Nothing)

selectPositionForDay : YearMonthDay -> Month -> (RowID, DayID)
selectPositionForDay ymd month =
  let dayIndex = (toWeekday ymd) - 1
  in
    Array.foldl (foldRowSelect dayIndex) defaultID month

foldPlaceDay : YearMonthDay -> Month -> Month
foldPlaceDay ymd inMonth =
  let 
    (rowID, dayID) = 
      (selectPositionForDay 
        ymd 
            inMonth)
    newRow = 
      case rowID.maybeRow of
        Just row -> Array.set 
          dayID.index 
          (Just ymd) 
              row
        Nothing -> rowDefault
  in
      (Array.set rowID.index newRow inMonth)

placeDays : Array YearMonthDay -> Month -> Month
placeDays ymd month =
  Array.foldl foldPlaceDay month ymd

makeGridFromMonth : YearMonth -> Month
makeGridFromMonth ym =
  let 
    days = makeDaysForMonth ym
  in
    placeDays days monthDefault

monthToWeekdays : List YearMonthDay -> List Weekdays
monthToWeekdays days =
  List.map toWeekday days |> List.map CalendarExtra.fromInt

update : Model -> Message -> (Model, Cmd Message)
update model message =
  (model, Cmd.none)

pairEmployeeShift : Settings -> (Employee, List Shift) -> List (Element msg)
pairEmployeeShift settings (employee, shifts) = 
  List.map (shiftElement settings employee) shifts

foldElementList : List (Element msg) -> List (Element msg) -> List (Element msg)
foldElementList nextList soFar =
  List.append soFar nextList

combineElementLists : List (List (Element msg)) -> List (Element msg)
combineElementLists lists =
  List.foldl foldElementList [] lists

formatLastName : Settings -> String -> String
formatLastName settings name =
  case settings.lastNameStyle of
    Session.FullName -> name
    Session.FirstInitial -> String.left 1 name
    Session.Hidden -> ""

shiftElement : 
  Settings 
  -> Employee
  -> Shift 
  -> Element msg
shiftElement settings employee shift =
  Element.el 
    [] (formatHours settings shift.hour shift.hours)

dayElement : 
  Settings 
  -> List (Employee, List Shift)
  -> Maybe YearMonthDay
  -> Element msg
dayElement settings employeeShifts maybeYMD =
  case maybeYMD of
    Just day -> Element.el [] Element.none
      -- (List.append 
      --   [text (String.fromInt day.day)]
      --   (combineHtmlLists (List.map 
      --     (pairEmployeeShift settings)
      --     (mapShiftsToYearMonthDay day employeeShifts))))
    Nothing -> Element.el [] Element.none
monthRowElement : 
  Settings 
  -> List (Employee, List Shift)
  -> Row 
  -> Element msg
monthRowElement settings employeeShifts row =
  Element.row [] []
  -- tr 
  --   [ 
  --     -- class "uk-container"
  --   ]
  --   (Array.toList (Array.map (dayElement settings employeeShifts) row))

monthElement = Element.el [] Element.none

view model =
  let 
    month = makeGridFromMonth (YearMonth 2019 3)
    settings = model.session.settings
    shiftDict = model.employeesData.employeeShifts
    employees = model.employeesData.employees
  in
    monthElement
    -- [
    --   table [
    --         class "uk-table",
    --         -- class "uk-table-divider",
    --         -- class "uk-flex", 
    --         class "uk-text-center" 
    --         -- class "uk-flex-row"
    --       ]
    --     (Array.toList (Array.map 
    --       (monthRowElement settings (mapEmployeeShifts shiftDict employees))
    --       month))
    -- ]
    