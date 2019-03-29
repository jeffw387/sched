module CalendarExtra exposing (..)
import Dict exposing (Dict)

monthCode : Dict Int Int
monthCode = 
  Dict.fromList
    [
      (1, 1),
      (2, 4),
      (3, 4),
      (4, 0),
      (5, 2),
      (6, 5),
      (7, 0),
      (8, 3),
      (9, 6),
      (10, 1),
      (11, 4),
      (12, 6)
    ]

centuryCode : Int -> Int
centuryCode year =
  let modyear = (modBy 400 year)
  in 
    if modyear >= 0 && modyear < 100
    then 6
    else if modyear >= 100 && modyear < 200
    then 4
    else if modyear >= 200 && modyear < 300
    then 2
    else 0

type alias YearMonthDay =
  {
    year : Int,
    month : Int,
    day : Int
  }

type alias YearMonth =
  {
    year : Int,
    month : Int
  }

type Weekdays =
  Sun |
  Mon |
  Tue |
  Wed |
  Thu |
  Fri |
  Sat |
  Invalid

fromInt : Int -> Weekdays
fromInt weekday =
  case weekday of
    1 -> Sun
    2 -> Mon
    3 -> Tue
    4 -> Wed
    5 -> Thu
    6 -> Fri
    7 -> Sat
    _ -> Invalid

withDay : YearMonth -> Int -> YearMonthDay
withDay ym d =
  YearMonthDay ym.year ym.month d

yearLastTwo : Int -> Int
yearLastTwo year =  
  if year >= 1000
    then yearLastTwo (year - 1000)
  else if year >= 100
    then yearLastTwo (year - 100)
  else year

isLeapYear : Int -> Bool
isLeapYear year = 
  modBy 4 year == 0

leapYearOffset : YearMonthDay -> Int
leapYearOffset ymd =
  if isLeapYear ymd.year then
    case ymd.month of
      1 -> -1
      2 -> -1
      _ -> 0
  else 0

daysInMonth : YearMonth -> Int
daysInMonth ym =
  case ym.month of
    1 -> 31
    2 -> case isLeapYear ym.year of
      True -> 29
      False -> 28
    3 -> 31
    4 -> 30
    5 -> 31
    6 -> 30
    7 -> 31
    8 -> 31
    9 -> 30
    10 -> 31
    11 -> 30
    12 -> 31
    _ -> 30

fromZellerWeekday : Int -> Int
fromZellerWeekday zellerDay =
  modBy 7 (zellerDay - 1) + 1

toWeekday : YearMonthDay -> Int
toWeekday ymd =
  let 
    lastTwo = yearLastTwo ymd.year
    centuryOffset = centuryCode ymd.year
  in
        fromZellerWeekday 
        <| remainderBy 7
        (lastTwo // 4 
        + ymd.day
        + Maybe.withDefault 0 (Dict.get ymd.month monthCode)
        + leapYearOffset ymd
        + centuryOffset
        + lastTwo)
