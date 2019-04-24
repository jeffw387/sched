module Main exposing (..)
import Browser
import Browser.Navigation as Nav
import Browser.Events
import Browser.Dom as Dom
import Url
import Json.Decode as D
import Json.Encode as E
import Task
import Http
import Url
import Url.Builder as UB
import Element exposing (..)
import Element.Font as Font
import Element.Input as Input
import Element.Background as BG
import Element.Border as Border
import Element.Events as Events
import Html.Attributes as HtmlAttr
import Json.Decode.Pipeline as JPipe
import Dict exposing (Dict)
import Array exposing (Array)
import List.Extra
import Time
import Simple.Fuzzy as Fuzzy
-- MAIN
main : Program () Model Message
main =
  Browser.application
    {
      init=init,
      view=view,
      update=update,
      subscriptions=subscriptions,
      onUrlChange=UrlChanged,
      onUrlRequest=UrlRequest
    }

-- MODEL
type ViewType =
  MonthView |
  WeekView |
  DayView

type HourFormat =
  Hour12 |
  Hour24

type LastNameStyle =
  FullName |
  FirstInitial |
  Hidden

type alias Settings =
  {
    id : Int,
    userID : Int,
    name : String,
    viewType : ViewType,
    hourFormat : HourFormat,
    lastNameStyle : LastNameStyle,
    viewDate : YearMonthDay,
    viewEmployees : List Int
  }

type EmployeeColor =
  Red |
  LightRed |
  Green |
  LightGreen |
  Blue |
  LightBlue |
  Yellow |
  LightYellow |
  Grey |
  LightGrey |
  Black |
  Brown

type alias ColorRecord =
  {
    red : Float,
    green : Float,
    blue : Float,
    alpha : Float
  }

type alias ColorPair =
  {
    light : ColorRecord,
    dark : ColorRecord
  }

employeeRGB : EmployeeColor -> ColorRecord
employeeRGB c =
  case c of
    Red -> 
      { red = 1, green = 0.25, blue = 0.25, alpha = 0 }
    LightRed -> 
      { red = 1, green = 0.5, blue = 0.5, alpha = 0 }
    Green -> 
      { red = 0.25, green = 1, blue = 0.25, alpha = 0 }
    LightGreen -> 
      { red = 0.5, green = 1, blue = 0.5, alpha = 0 }
    Blue -> 
      { red = 0.25, green = 0.25, blue = 1, alpha = 0 }
    LightBlue -> 
      { red = 0.5, green = 0.5, blue = 1, alpha = 0 }
    Yellow -> 
      { red = 1, green = 1, blue = 0.25, alpha = 0 }
    LightYellow -> 
      { red = 1, green = 1, blue = 0.5, alpha = 0 }
    Grey -> 
      { red = 0.5, green = 0.5, blue = 0.5, alpha = 0 }
    LightGrey -> 
      { red = 0.95, green = 0.95, blue = 0.95, alpha = 0 }
    Black -> 
      { red = 0.25, green = 0.25, blue = 0.25, alpha = 0 }
    Brown -> 
      { red = 0.65, green = 0.35, blue = 0.2, alpha = 0 }

employeeColor : EmployeeColor -> ColorPair
employeeColor c =
  let crgb = employeeRGB c in
  ColorPair
  {crgb | alpha = 0.25}
  {crgb | alpha = 1}

type alias PerEmployeeSettings =
  {
    id : Int,
    settingsID : Int,
    employeeID : Int,
    color : EmployeeColor
  }

type alias CombinedSettings =
  {
    settings : Settings,
    perEmployee : List PerEmployeeSettings
  }

ymdPriorMonth : YearMonthDay -> YearMonthDay
ymdPriorMonth ymd =
  case ymd.month of
    1 -> { ymd | year = ymd.year - 1, month = 12 }
    _ -> { ymd | month = ymd.month - 1 }

ymdNextMonth : YearMonthDay -> YearMonthDay
ymdNextMonth ymd =
  case ymd.month of
    12 -> { ymd | year = ymd.year + 1, month = 1 }
    _ -> { ymd | month = ymd.month + 1 }

type InputState =
  Normal |
  Success |
  Danger |
  Disabled

type alias LoginInfo = 
  {
    email : String,
    password : String
  }

type UserLevel =
  Read |
  Supervisor |
  Admin

type alias User =
  {
    id : Int,
    level : UserLevel
  }

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

employeeDefault =
  Employee 0 (Name "" "") Nothing

type alias HoverData =
  {

  }

type alias LoginModel =
  {
    loginInfo : LoginInfo,
    emailState : InputState,
    passwordState : InputState,
    buttonState : InputState
  }

defaultLoginModel =
  LoginModel
  (LoginInfo "" "")
  Normal
  Normal
  Normal

type CalendarModal =
  NoModal |
  ViewSelectModal |
  ViewEditModal ViewEditData |
  ShiftModal ShiftModalData

type alias CalendarData =
  {
    modal : CalendarModal
  }

defaultCalendarModel =
  CalendarData
  NoModal

type Page =
  LoginPage LoginModel |
  CalendarPage CalendarData

type alias Model =
  {
    navkey : Nav.Key,
    -- loaded data
    settingsList : Maybe (List CombinedSettings),
    activeSettings : Maybe Int,
    user : Maybe User,
    employees : Maybe (List Employee),
    shifts : Maybe (List Shift),
    posixNow : Maybe Time.Posix,
    here : Maybe Time.Zone,

    -- per page data
    page : Page
  }

type alias Shift =
  {
    id : Int,
    userID : Int,
    employeeID : Int,
    year : Int,
    month : Int,
    day : Int,
    hour : Int,
    minute : Int,
    hours : Int,
    minutes : Int,
    repeat : ShiftRepeat,
    everyX : Int
  }

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

monthToNum month =
  case month of
    Time.Jan -> 1
    Time.Feb -> 2
    Time.Mar -> 3
    Time.Apr -> 4
    Time.May -> 5
    Time.Jun -> 6
    Time.Jul -> 7
    Time.Aug -> 8
    Time.Sep -> 9
    Time.Oct -> 10
    Time.Nov -> 11
    Time.Dec -> 12

monthNumToString num =
  case num of
    1 -> "January"
    2 -> "February"
    3 -> "March"
    4 -> "April"
    5 -> "May"
    6 -> "June"
    7 -> "July"
    8 -> "August"
    9 -> "September"
    10 -> "October"
    11 -> "November"
    12 -> "December"
    _ -> "Unknown"

weekdayNumToString num =
  case num of
    1 -> "Sunday"
    2 -> "Monday"
    3 -> "Tuesday"
    4 -> "Wednesday"
    5 -> "Thursday"
    6 -> "Friday"
    7 -> "Saturday"
    _ -> "Unknown"

-- SERIALIZATION
encodeLoginInfo : LoginInfo -> E.Value
encodeLoginInfo loginValue =
  E.object
    [
      ("email", E.string loginValue.email),
      ("password", E.string loginValue.password)
    ]

nameEncoder : Name -> E.Value
nameEncoder n =
  E.object 
    [
      ("first", E.string n.first),
      ("last", E.string n.last)
    ]

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

userLevelEncoder : UserLevel -> E.Value
userLevelEncoder level =
  case level of
    Supervisor -> E.string "Supervisor"
    Admin -> E.string "Admin"
    _ -> E.string "Read"

userEncoder : User -> E.Value
userEncoder user =
  E.object
    [
      ("id", E.int user.id),
      ("level", userLevelEncoder user.level)
    ]

viewTypeEncoder : ViewType -> E.Value
viewTypeEncoder viewType =
  case viewType of
    MonthView -> E.string "Month"
    WeekView -> E.string "Week"
    DayView -> E.string "Day"

hourFormatEncoder : HourFormat -> E.Value
hourFormatEncoder hourFormat =
  case hourFormat of
    Hour12 -> E.string "Hour12"
    Hour24 -> E.string "Hour24"

lastNameStyleEncoder : LastNameStyle -> E.Value
lastNameStyleEncoder lastNameStyle =
  case lastNameStyle of
    FullName -> E.string "FullName"
    FirstInitial -> E.string "FirstInitial"
    Hidden -> E.string "Hidden"

shiftRepeatEncoder : ShiftRepeat -> E.Value
shiftRepeatEncoder repeat =
  case repeat of
    NeverRepeat -> E.string "NeverRepeat"
    EveryWeek -> E.string "EveryWeek"
    EveryDay -> E.string "EveryDay"

settingsEncoder : Settings -> E.Value
settingsEncoder settings =
  E.object
    [
      ("id", E.int settings.id),
      ("user_id", E.int settings.userID),
      ("name", E.string settings.name),
      ("view_type", viewTypeEncoder settings.viewType),
      ("hour_format", hourFormatEncoder settings.hourFormat),
      ("last_name_style", lastNameStyleEncoder settings.lastNameStyle),
      ("view_year", E.int settings.viewDate.year),
      ("view_month", E.int settings.viewDate.month),
      ("view_day", E.int settings.viewDate.day),
      ("view_employees", E.list E.int settings.viewEmployees)
    ]

employeeColorEncoder : EmployeeColor -> E.Value
employeeColorEncoder c =
  let 
    str = 
      case c of
        Red -> "Red"
        LightRed -> "LightRed"
        Green -> "Green"
        LightGreen -> "LightGreen"
        Blue -> "Blue"
        LightBlue -> "LightBlue"
        Yellow -> "Yellow"
        LightYellow -> "LightYellow"
        Grey -> "Grey"
        LightGrey -> "LightGrey"
        Black -> "Black"
        Brown -> "Brown"
  in E.string str

perEmployeeSettingsEncoder : PerEmployeeSettings -> E.Value
perEmployeeSettingsEncoder perEmployee =
  E.object
    [
    ("id", E.int perEmployee.id),
    ("settings_id", E.int perEmployee.settingsID),
    ("employee_id", E.int perEmployee.employeeID),
    ("color", employeeColorEncoder perEmployee.color)
    ]


newShiftEncoder : Shift -> E.Value
newShiftEncoder shift =
  E.object
    [
      ("user_id", E.int shift.userID),
      ("employee_id", E.int shift.employeeID),
      ("year", E.int shift.year),
      ("month", E.int shift.month),
      ("day", E.int shift.day),
      ("hour", E.int shift.hour),
      ("minute", E.int shift.minute),
      ("hours", E.int shift.hours),
      ("minutes", E.int shift.minutes),
      ("shift_repeat", shiftRepeatEncoder shift.repeat),
      ("every_x", E.int shift.everyX)
    ]

shiftEncoder : Shift -> E.Value
shiftEncoder shift =
  E.object
    [
      ("id", E.int shift.id),
      ("user_id", E.int shift.userID),
      ("employee_id", E.int shift.employeeID),
      ("year", E.int shift.year),
      ("month", E.int shift.month),
      ("day", E.int shift.day),
      ("hour", E.int shift.hour),
      ("minute", E.int shift.minute),
      ("hours", E.int shift.hours),
      ("minutes", E.int shift.minutes),
      ("shift_repeat", shiftRepeatEncoder shift.repeat),
      ("every_x", E.int shift.everyX)
    ]

-- DESERIALIZATION
viewYMDDecoder =
  D.succeed YearMonthDay
  |> JPipe.required "view_year" D.int
  |> JPipe.required "view_month" D.int
  |> JPipe.required "view_day" D.int

settingsDecoder : D.Decoder Settings
settingsDecoder =
  D.succeed Settings
  |> JPipe.required "id" D.int
  |> JPipe.required "user_id" D.int
  |> JPipe.required "name" D.string
  |> JPipe.required "view_type" viewTypeDecoder
  |> JPipe.required "hour_format" hourFormatDecoder
  |> JPipe.required "last_name_style" lastNameStyleDecoder
  |> JPipe.custom viewYMDDecoder
  |> JPipe.required "view_employees" (D.list D.int)

employeeColorDecoder : D.Decoder EmployeeColor
employeeColorDecoder =
  D.string
  |> D.andThen
    (
      \color -> 
        D.succeed <|
        case color of
          "Red" -> Red
          "LightRed" -> LightRed
          "Green" -> Green
          "LightGreen" -> LightGreen
          "LightBlue" -> LightBlue
          "Yellow" -> Yellow
          "LightYellow" -> LightYellow
          "Grey" -> Grey
          "LightGrey" -> LightGrey
          "Black" -> Black
          "Brown" -> Brown
          _ -> Blue
    )

perEmployeeSettingsDecoder : D.Decoder PerEmployeeSettings
perEmployeeSettingsDecoder =
  D.succeed PerEmployeeSettings
  |> JPipe.required "id" D.int
  |> JPipe.required "settings_id" D.int
  |> JPipe.required "employee_id" D.int
  |> JPipe.required "color" employeeColorDecoder

combinedSettingsDecoder : D.Decoder CombinedSettings
combinedSettingsDecoder =
  D.succeed CombinedSettings
  |> JPipe.required "settings" settingsDecoder
  |> JPipe.required "per_employee" (D.list perEmployeeSettingsDecoder)

viewTypeDecoder : D.Decoder ViewType
viewTypeDecoder =
  D.string
  |> D.andThen
    (
      \viewTypeString ->
        case viewTypeString of
          "Week" -> D.succeed WeekView
          "Day" -> D.succeed DayView
          _ -> D.succeed MonthView
    )

hourFormatDecoder : D.Decoder HourFormat
hourFormatDecoder =
  D.string
  |> D.andThen
    (
      \hourFormatString ->
        case hourFormatString of
          "Hour24" -> D.succeed Hour24
          _ -> D.succeed Hour12
    )

lastNameStyleDecoder : D.Decoder LastNameStyle
lastNameStyleDecoder =
  D.string
  |> D.andThen
    (
      \styleString ->
        case styleString of
          "FirstInitial" -> D.succeed FirstInitial
          "Hidden" -> D.succeed Hidden
          _ -> D.succeed FullName
    )

nameDecoder : D.Decoder Name
nameDecoder =
  D.succeed Name
  |> JPipe.required "first" D.string
  |> JPipe.required "last" D.string

genericObjectDecoder : D.Decoder a -> D.Decoder a
genericObjectDecoder f =
  D.field "contents" f

employeeDecoder : D.Decoder Employee
employeeDecoder =
  D.succeed Employee
  |> JPipe.required "id" D.int
  |> JPipe.requiredAt ["name"] nameDecoder
  |> JPipe.required "phone_number" (D.maybe D.string)

shiftRepeatDecoder : D.Decoder ShiftRepeat
shiftRepeatDecoder =
  D.string
  |> D.andThen 
    (
      \string -> 
      case string of
        "EveryWeek" -> D.succeed EveryWeek
        "EveryDay" -> D.succeed EveryDay
        _ -> D.succeed NeverRepeat
    )

shiftDecoder : D.Decoder Shift
shiftDecoder =
  D.succeed Shift
    |> JPipe.required "id" D.int
    |> JPipe.required "user_id" D.int
    |> JPipe.required "employee_id" D.int
    |> JPipe.required "year" D.int
    |> JPipe.required "month" D.int
    |> JPipe.required "day" D.int
    |> JPipe.required "hour" D.int
    |> JPipe.required "minute" D.int
    |> JPipe.required "hours" D.int
    |> JPipe.required "minutes" D.int
    |> JPipe.required "shift_repeat" shiftRepeatDecoder
    |> JPipe.required "every_x" D.int

userLevelDecoder : D.Decoder UserLevel
userLevelDecoder =
  D.string
  |> D.andThen 
    (
      \levelString -> case levelString of
        "Supervisor" -> D.succeed Supervisor
        "Admin" -> D.succeed Admin
        _ -> D.succeed Read
    )

userDecoder = D.succeed User
  |> JPipe.required "id" D.int
  |> JPipe.required "level" userLevelDecoder

type Keys =
  Left |
  Up |
  Right |
  Down |
  Enter |
  Escape

keyDecoder =
  D.map keyMap (D.field "key" D.string)

keyMap string =
  case string of
    "ArrowLeft" -> Just Left
    "ArrowUp" -> Just Up
    "ArrowRight" -> Just Right
    "ArrowDown" -> Just Down
    "Enter" -> Just Enter
    "Escape" -> Just Escape
    _ -> Nothing

-- SUBSCRIPTIONS
subscriptions : Model -> Sub Message
subscriptions _ =
    Sub.map KeyDown (Browser.Events.onKeyDown keyDecoder)

-- INIT
settingsDefault = 
  Settings
    0
    0
    "New View"
    MonthView 
    Hour12 
    FirstInitial
    (YearMonthDay 2019 3 23)
    []

init : () -> Url.Url -> Nav.Key -> (Model, Cmd Message)
init _ url key =
  router 
    (
      Model 
        key
        Nothing
        Nothing
        Nothing
        Nothing
        Nothing
        Nothing
        Nothing
        (LoginPage defaultLoginModel)
    ) url

-- UPDATE
type Message =
-- General Messages
  NoOp |
  IgnoreReply (Result Http.Error ()) |
  UrlChanged Url.Url |
  UrlRequest Browser.UrlRequest |
  Logout |
  KeyDown (Maybe Keys) |
  FocusResult (Result Dom.Error ()) |
-- Login Messages
  LoginRequest |
  LoginResponse (Result Http.Error ()) |
  UpdateEmail String |
  UpdatePassword String |
-- Calendar Messages
  OverShift (Employee, Shift) |
  LeaveShift |
  DayClick (Maybe YearMonthDay) |
  PriorMonth |
  NextMonth |
  -- ShiftModal Messages
  OpenShiftModal (Maybe YearMonthDay) (Maybe Shift) |
  AddShift |
  UpdateShiftRequest Shift |
  CloseShiftModal |
  ShiftEmployeeSearch String |
  ChooseShiftEmployee Employee |
  UpdateShiftStart Float |
  UpdateShiftDuration Float |
  UpdateShiftRepeat ShiftRepeat |
  UpdateShiftRepeatRate String |
  -- ViewSelect Messages
  OpenViewSelect |
  ChooseActiveView Int |
  DuplicateView |
  CloseViewSelect |
  -- View Edit Messages
  OpenViewEdit |
  UpdateViewName String |
  UpdateViewType ViewType |
  UpdateHourFormat HourFormat |
  UpdateLastNameStyle LastNameStyle |
  EmployeeViewCheckbox Int Bool |
  OpenEmployeeColorSelector Employee |
  ChooseEmployeeColor Employee EmployeeColor |
  SaveView |
  CloseViewEdit |
  -- Loading Messages
  ReceiveEmployees (Result Http.Error (List Employee)) |
  ReceiveShifts (Result Http.Error (List Shift)) |
  ReceiveDefaultSettings (Result Http.Error (Maybe Int)) |
  ReceiveSettingsList (Result Http.Error (List CombinedSettings)) |
  ReceivePosixTime Time.Posix |
  ReceiveZone Time.Zone |
  ReloadData (Result Http.Error ())

getEmployeeSettings : Model -> Int -> Maybe PerEmployeeSettings
getEmployeeSettings model id =
  case getActiveSettings model of
    Just active ->
      List.filter 
      (\p_e -> p_e.employeeID == id)
      active.perEmployee
      |> List.head
    Nothing -> Nothing

loginRequest : LoginInfo -> (Cmd Message)
loginRequest loginInfo =
  Http.post
    {
      url = UB.absolute ["sched", "login_request"][],
      body = Http.jsonBody (encodeLoginInfo loginInfo),
      expect = Http.expectWhatever LoginResponse
    }

updateLoginButton : LoginModel -> LoginModel
updateLoginButton page =
  if page.emailState == Success && 
    page.passwordState == Success
    then { page | buttonState = Success }
    else { page | buttonState = Normal }

nameToString : Name -> String
nameToString name =
  name.first ++ " " ++ name.last

requestEmployees : Cmd Message
requestEmployees =
  Http.post 
  {
    url="/sched/get_employees",
    body=Http.emptyBody,
    expect=Http.expectJson ReceiveEmployees (genericObjectDecoder (D.list employeeDecoder))
  }

requestShifts : Cmd Message
requestShifts =
  Http.post {
    url = "/sched/get_shifts",
    body = Http.emptyBody,
    expect = Http.expectJson ReceiveShifts (genericObjectDecoder (D.list shiftDecoder))
  } 

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

-- weekdayFromInt : Int -> Weekdays
-- weekdayFromInt weekday =
--   case weekday of
--     1 -> Sun
--     2 -> Mon
--     3 -> Tue
--     4 -> Wed
--     5 -> Thu
--     6 -> Fri
--     7 -> Sat
--     _ -> Invalid

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

hourMinuteToFloat : Int -> Int -> Float
hourMinuteToFloat hour minute =
  let
    fraction = toFloat (round ((toFloat minute) / 15)) / 4
  in (toFloat hour) + fraction

shiftEditorForShift : Shift -> List Employee -> ShiftModalData
shiftEditorForShift shift employees =
  ShiftModalData
    (Just shift)
    (getEmployee employees shift.employeeID)
    ""
    employees
    (ymdFromShift shift)
    (hourMinuteToFloat shift.hour shift.minute)
    (hourMinuteToFloat shift.hours shift.minutes)
    shift.repeat
    (String.fromInt shift.everyX)

shiftEditorForDay : YearMonthDay -> List Employee -> ShiftModalData
shiftEditorForDay day employees =
  ShiftModalData
    Nothing
    Nothing
    ""
    employees
    day
    8
    8
    NeverRepeat
    "1"

loadData =
  Cmd.batch 
    [
      getPosixTime, 
      getTimeZone, 
      requestEmployees, 
      requestShifts, 
      requestSettings,
      requestDefaultSettings
    ]

router : Model -> Url.Url -> (Model, Cmd Message)
router model url =
    case url.path of
      "/sched" -> 
        let 
          updated = { model | page = CalendarPage defaultCalendarModel } 
        in
          (updated, loadData)
      "/sched/calendar" ->
        let 
          updated = { model | page = CalendarPage defaultCalendarModel }
        in
          (updated, loadData)
      "/sched/login" ->
        ({ model | page = LoginPage defaultLoginModel }, Cmd.none)
      _ ->
        ({ model | page = LoginPage defaultLoginModel }, Cmd.none)

requestSettings =
  Http.post
    {
      url = "/sched/get_settings",
      body = Http.emptyBody,
      expect = Http.expectJson 
        ReceiveSettingsList 
        <| genericObjectDecoder 
        (D.list combinedSettingsDecoder)
    }

requestDefaultSettings =
  Http.post
    {
      url = "/sched/default_settings",
      body = Http.emptyBody,
      expect = Http.expectJson 
        ReceiveDefaultSettings 
        <| genericObjectDecoder 
        (D.maybe D.int)
    }

getTime posixTime here =
      YearMonthDay
        (Time.toYear here posixTime)
        (monthToNum (Time.toMonth here posixTime))
        (Time.toDay here posixTime)

getTimeZone : Cmd Message
getTimeZone =
  Task.perform ReceiveZone Time.here

getPosixTime : Cmd Message
getPosixTime =
  Task.perform ReceivePosixTime Time.now

getSettings : Model -> Int -> Maybe CombinedSettings
getSettings model index =
  case model.settingsList of
    Just settingsList ->
      List.filter (\s -> s.settings.id == index) settingsList 
      |> List.head
    _ -> Nothing

getActiveSettings : Model -> Maybe CombinedSettings
getActiveSettings model =
  case (model.activeSettings, model.settingsList) of
    (Just activeID, Just settingsList) ->
      List.filter (\s -> s.settings.id == activeID) settingsList
      |> List.head
    _ -> Nothing

shiftFromModal : ShiftModalData -> Maybe Shift
shiftFromModal shiftData =
  case (shiftData.employee, String.toInt shiftData.everyX, shiftData.priorShift) of
    (Just employee, Just everyX, Nothing) ->
      Just (Shift
      0
      0
      employee.id
      shiftData.ymd.year
      shiftData.ymd.month
      shiftData.ymd.day
      (floatToHour shiftData.start)
      (floatToQuarterHour shiftData.start)
      (floor shiftData.duration)
      (floatToQuarterHour shiftData.duration)
      shiftData.shiftRepeat
      everyX)
    (Just employee, Just everyX, Just prior) ->
      Just 
        { 
          prior | 
          employeeID = employee.id,
          year = shiftData.ymd.year,
          month = shiftData.ymd.month,
          day = shiftData.ymd.day,
          hour = (floatToHour shiftData.start),
          minute = (floatToQuarterHour shiftData.start),
          hours = (floor shiftData.duration),
          minutes = (floatToQuarterHour shiftData.duration),
          repeat = shiftData.shiftRepeat,
          everyX = everyX
        }
    _ -> Nothing

updateSettings : Settings -> Cmd Message
updateSettings settings =
  Http.post
  {
    url = "/sched/update_settings",
    body =
    Http.jsonBody
    <| settingsEncoder settings,
    expect = Http.expectWhatever ReloadData
  }

update : Message -> Model -> (Model, Cmd Message)
update message model =
  -- let debug = Debug.log "Message" (message) in
  case (model.page, message) of
  
  -- General messages
    (_, UrlRequest request) ->
      case request of
        Browser.Internal url ->
          (model, Nav.pushUrl model.navkey (Url.toString url))
        _ -> (model, Cmd.none)
    (_, UrlChanged url) ->
      router model url
    (_, Logout) ->
      (
        model, 
        Http.post
        {
          url = UB.absolute ["sched", "logout_request"] [],
          body = Http.emptyBody,
          expect = Http.expectWhatever IgnoreReply
        }
      )
    (_, IgnoreReply _) ->
      (model, Nav.pushUrl model.navkey "/sched/login")
      
  -- Login messages
    (LoginPage page, LoginRequest) ->
      (model, loginRequest page.loginInfo)
    (LoginPage page, LoginResponse r) ->
      let 
        updatedPage =
          { 
            page | loginInfo = 
              LoginInfo "" "" 
          }
        updatedModel = 
          { 
            model | page = LoginPage updatedPage
          } 
      in
        case r of
          Ok _ ->
            (updatedModel, 
              Nav.pushUrl 
                model.navkey
                "/sched/calendar"
            )
          Err _ -> (updatedModel, Cmd.none)
    (LoginPage page, UpdateEmail email) ->
      let 
        info = page.loginInfo
        updatedInfo = { info | email = email }
        updatedPage = { page | loginInfo = updatedInfo }
        updatedModel = { model | page = LoginPage updatedPage }
      in (updatedModel, Cmd.none)
    (LoginPage page, UpdatePassword password) ->
      let
        info = page.loginInfo
        updatedInfo = { info | password = password }
        updatedPage = { page | loginInfo = updatedInfo }
        updatedModel = { model | page = LoginPage updatedPage }
      in (updatedModel, Cmd.none)
      
  -- Loading messages
    (_, ReceiveEmployees employeesResult) ->
      case employeesResult of
        Ok employees ->
          let 
            sortedEmps = 
              List.sortWith 
              (\e1 e2 -> 
                compare (nameToString e1.name) (nameToString e2.name)) 
                employees
            updated = { model | employees = Just sortedEmps }
          in
            (updated, Cmd.none)
        Err e ->
          (model, Nav.pushUrl model.navkey "/sched/login")
    (_, ReceiveShifts shiftsResult) ->
      case shiftsResult of
        Ok shifts ->
              ({ model | shifts = 
                  Just shifts }, Cmd.none)
        Err e -> 
          (model, Cmd.none)
    (_, ReceiveSettingsList settingsResult) ->
      (case settingsResult of
        Ok settingsList ->
          (
            {
              model | settingsList = Just settingsList
            },
            Cmd.none
          )
        Err e -> (model, Cmd.none))
    (_, ReceivePosixTime posixTime) ->
      let
        updatedModel = { model | posixNow = Just posixTime }
      in (updatedModel, Cmd.none)
    (_, ReceiveZone here) ->
      let
        updatedModel = { model | here = Just here }
      in (updatedModel, Cmd.none)
    (_, ReceiveDefaultSettings settingsResult) ->
      case settingsResult of
        Ok settingsMaybe ->
          case settingsMaybe of
            Just settings ->
              let 
                updated = { model | activeSettings = Just settings }
              in (updated, Cmd.none)
            Nothing -> (model, Cmd.none)
        Err _ -> (model, Cmd.none)
    (_, ReloadData _) ->
      let 
        updated = 
          { 
            model | 
              settingsList = Nothing,
              activeSettings = Nothing,
              user = Nothing,
              employees = Nothing,
              shifts = Nothing,
              posixNow = Nothing,
              here = Nothing
          }
      in (model, loadData)
      
  -- View select messages
    (CalendarPage page, OpenViewSelect) ->
      case page.modal of
        NoModal ->
          let
            updatedPage = { page | modal = 
              ViewSelectModal }
            updatedModel = { model | page = CalendarPage updatedPage }
          in (updatedModel, Cmd.none)
        _ -> (model, Cmd.none)
    (CalendarPage page, ChooseActiveView activeID) ->
      case page.modal of
        ViewSelectModal ->
          case getSettings model activeID of
            Just active ->
              (model, 
              Http.post
                {
                  url = "/sched/set_default_settings",
                  body = Http.jsonBody 
                    <| settingsEncoder active.settings,
                  expect = Http.expectWhatever ReloadData
                })
            Nothing -> (model, Cmd.none)
        _ -> (model, Cmd.none)
    (CalendarPage page, CloseViewSelect) ->
      case page.modal of
        ViewSelectModal ->
          let
            updatedPage = { page | modal = NoModal }
            updatedModel = { model | page = CalendarPage updatedPage }
          in (updatedModel, Cmd.none)
        _ -> (model, Cmd.none)
    (CalendarPage page, DuplicateView) ->
      case getActiveSettings model of
        Just active ->
          (model,
            Http.post
            {
              url = "/sched/add_settings",
              body = Http.jsonBody 
                <| settingsEncoder
                active.settings,
              expect = Http.expectWhatever
                ReloadData
            })
        Nothing -> (model, Cmd.none)
        
  -- View edit messages
    (CalendarPage page, OpenViewEdit) ->
      case (page.modal, getActiveSettings model) of
        (NoModal, Just active) ->
          let
            updatedPage = { page | modal = 
              ViewEditModal <| defaultViewEdit active.settings}
            updatedModel = { model | page = CalendarPage updatedPage }
          in (updatedModel, Cmd.none)
        _ -> (model, Cmd.none)
    (CalendarPage page, UpdateViewName name) ->
      case (page.modal, getActiveSettings model) of 
        (ViewEditModal _, Just active) ->
          let
            settings = active.settings
            updatedSettings = { settings | name = name }
          in
            (model, updateSettings updatedSettings)
        _ -> (model, Cmd.none)
    (CalendarPage page, UpdateViewType viewType) ->
      case (page.modal, getActiveSettings model) of 
        (ViewEditModal _, Just active) ->
          let
            settings = active.settings
            updatedSettings = { settings | viewType = viewType }
          in
            (model, updateSettings updatedSettings)
        _ -> (model, Cmd.none)
    (CalendarPage page, UpdateHourFormat hourFormat) ->
      case (page.modal, getActiveSettings model) of 
        (ViewEditModal _, Just active) ->
          let
            settings = active.settings
            updatedSettings = { settings | hourFormat = hourFormat }
          in
            (model, updateSettings updatedSettings)
        _ -> (model, Cmd.none)
    (CalendarPage page, UpdateLastNameStyle lastNameStyle) ->
      case (page.modal, getActiveSettings model) of 
        (ViewEditModal _, Just active) ->
          let
            settings = active.settings
            updatedSettings = { settings | lastNameStyle = lastNameStyle }
          in
            (model, updateSettings updatedSettings)
        _ -> (model, Cmd.none)
    (CalendarPage page, EmployeeViewCheckbox id checked) ->
      case (page.modal, getActiveSettings model) of 
        (ViewEditModal _, Just active) ->
          let
            settings = active.settings
            viewEmployees = settings.viewEmployees
            updatedEmployees = case checked of
              True -> id :: viewEmployees |> List.Extra.unique
              False -> List.Extra.remove id viewEmployees
            updatedSettings = { settings | viewEmployees = updatedEmployees }
          in
            (model, updateSettings updatedSettings)
        _ -> (model, Cmd.none)
    (CalendarPage page, OpenEmployeeColorSelector employee) ->
      case page.modal of 
        ViewEditModal editData ->
          let
            updatedData = {editData | colorSelect = Just employee}
            updatedPage = {page | modal = ViewEditModal updatedData}
            updatedModel = {model | page = CalendarPage updatedPage}
          in (updatedModel, Cmd.none)
        _ -> (model, Cmd.none)
    (CalendarPage page, ChooseEmployeeColor employee color) ->
      case (page.modal, getEmployeeSettings model employee.id, getActiveSettings model) of 
        (ViewEditModal editData, Just perEmployee, _) ->
          let
            updatedData = {editData | colorSelect = Nothing}
            updatedPage = {page | modal = ViewEditModal updatedData}
            updatedModel = {model | page = CalendarPage updatedPage}
            updatedPerEmployee = {perEmployee | color = color}
          in (updatedModel, 
            Http.post
            {
              url = "/sched/update_employee_settings",
              body = Http.jsonBody 
                (perEmployeeSettingsEncoder updatedPerEmployee),
              expect = Http.expectWhatever ReloadData
            })
        (ViewEditModal editData, Nothing, Just active) ->
          let
            updatedData = {editData | colorSelect = Nothing}
            updatedPage = {page | modal = ViewEditModal updatedData}
            updatedModel = {model | page = CalendarPage updatedPage}
            perEmployee = 
              PerEmployeeSettings 
              0 
              active.settings.id 
              employee.id 
              color
          in (updatedModel, 
            Http.post
            {
              url = "/sched/add_employee_settings",
              body = Http.jsonBody 
                (perEmployeeSettingsEncoder perEmployee),
              expect = Http.expectWhatever ReloadData
            })
        _ -> (model, Cmd.none)
    (CalendarPage page, CloseViewEdit) ->
      case page.modal of
        ViewEditModal editData ->
          let
            updatedPage = { page | modal = NoModal }
            updatedModel = { model | page = CalendarPage updatedPage }
          in (updatedModel, Cmd.none)
        _ -> (model, Cmd.none)
  
  -- Shift edit messages
    (CalendarPage page, OpenShiftModal maybeDay maybeShift) ->
      case (page.modal, maybeDay, maybeShift) of
        (NoModal, Just day, Nothing) -> 
          case getActiveSettings model of
            Just active ->
              let 
                filteredEmployees = (getViewEmployees 
                  (Maybe.withDefault [] model.employees) 
                  active.settings.viewEmployees)
                updatedPage = { page | modal = 
                  ShiftModal 
                  (shiftEditorForDay day filteredEmployees) }
                updatedModel = { model | page = CalendarPage updatedPage }
              in (updatedModel, 
                Task.attempt 
                FocusResult 
                (Dom.focus "employeeSearch"))
            Nothing -> (model, Cmd.none)
        (NoModal, Nothing, Just shift) ->
          case getActiveSettings model of
            Just active ->
              let 
                filteredEmployees = (getViewEmployees 
                  (Maybe.withDefault [] model.employees) 
                  active.settings.viewEmployees)
                updatedPage = { page | modal = 
                  ShiftModal 
                    (shiftEditorForShift shift filteredEmployees) }
                updatedModel = { model | page = CalendarPage updatedPage }
              in
                (updatedModel,
                  Task.attempt 
                  FocusResult 
                  (Dom.focus "employeeSearch"))
            Nothing -> (model, Cmd.none)
        _ -> (model, Cmd.none)
    (CalendarPage page, CloseShiftModal) ->
      case page.modal of
        ShiftModal _ ->
          let 
            updatedPage = { page | modal = NoModal }
            updatedModel = { model | page = CalendarPage updatedPage }
          in
            (updatedModel, Cmd.none)
        _ -> (model, Cmd.none)
    (CalendarPage page, ShiftEmployeeSearch searchText) ->
      case (page.modal, getActiveSettings model) of
        (ShiftModal shiftModalData, Just active) ->
          let 
            filteredEmployees = (getViewEmployees 
                (Maybe.withDefault [] model.employees) 
                active.settings.viewEmployees)
            newMatches = Fuzzy.filter
              (\emp -> nameToString emp.name)
              searchText
              filteredEmployees
            updatedModal = { shiftModalData | 
              employeeSearch = searchText,
              employeeMatches = newMatches }
            updatedPage = 
              { page | modal = ShiftModal updatedModal }
            updatedModel = 
              { model | page = CalendarPage updatedPage } 
          in
            if List.length newMatches == 1 
            then 
              case List.head newMatches of
                Just oneEmp -> 
                  update 
                  (ChooseShiftEmployee oneEmp) 
                  updatedModel
                Nothing -> (updatedModel, Cmd.none)
            else (updatedModel, Cmd.none)
        _ -> (model, Cmd.none)
    (CalendarPage page, ChooseShiftEmployee employee) ->
      case page.modal of
        ShiftModal shiftModalData ->
          let
            updatedModal = { shiftModalData | employee = Just employee }
            updatedPage = { page | modal = ShiftModal updatedModal }
            updatedModel = { model | page = CalendarPage updatedPage }
          in (updatedModel, Cmd.none)
        _ -> (model, Cmd.none)
    (CalendarPage page, AddShift) ->
      case page.modal of
        ShiftModal shiftData ->
          case shiftFromModal shiftData of
            Just shift ->
              let
                updatedPage = { page | modal = NoModal }
                updatedModel = { model | page = CalendarPage updatedPage }
              in
              (updatedModel, Http.post
                {
                  url = "/sched/add_shift",
                  body = Http.jsonBody (newShiftEncoder shift),
                  expect = Http.expectWhatever ReloadData
                })
            Nothing -> (model, Cmd.none)
        _ -> (model, Cmd.none)
    (CalendarPage page, UpdateShiftRequest shift) ->
      (model, Http.post
        {
          url = "/sched/update_shift",
          body = Http.jsonBody (shiftEncoder shift),
          expect = Http.expectWhatever ReloadData
        })
    (CalendarPage page, UpdateShiftRepeat shiftRepeat) -> 
      case page.modal of
        ShiftModal shiftData ->
          let
            updatedShiftData = 
              { 
                shiftData | 
                  shiftRepeat = shiftRepeat
              }
            updatedPage = { page | modal = ShiftModal updatedShiftData }
            updatedModel = { model | page = CalendarPage updatedPage }
          in (updatedModel, Cmd.none)
        _ -> (model, Cmd.none)
    (CalendarPage page, UpdateShiftRepeatRate rate) ->
      case page.modal of
        ShiftModal shiftData ->
          let
            updatedShiftData = { shiftData | everyX = rate }
            updatedPage = { page | modal = ShiftModal updatedShiftData }
            updatedModel = { model | page = CalendarPage updatedPage }
          in (updatedModel, Cmd.none)
        _ -> (model, Cmd.none)
    (CalendarPage page, UpdateShiftStart f) ->
      case page.modal of
        ShiftModal shiftModalData ->
          let
            updatedModal = { shiftModalData | start = f }
            updatedPage = { page | modal = ShiftModal updatedModal }
            updatedModel = { model | page = CalendarPage updatedPage }
          in (updatedModel, Cmd.none)
        _ -> (model, Cmd.none)
    (CalendarPage page, UpdateShiftDuration f) ->
      case page.modal of
        ShiftModal shiftModalData ->
          let
            updatedModal = { shiftModalData | duration = f }
            updatedPage = { page | modal = ShiftModal updatedModal }
            updatedModel = { model | page = CalendarPage updatedPage }
          in (updatedModel, Cmd.none)
        _ -> (model, Cmd.none)

  -- Calendar messages
    (CalendarPage page, KeyDown maybeKey) ->
      (model, Cmd.none)
    (CalendarPage page, PriorMonth) ->
      case getActiveSettings model of
        Just active ->
          let settings = active.settings in
          (model, Http.post
          {
            url = "/sched/update_settings",
            body = Http.jsonBody
              <| settingsEncoder { settings | 
                viewDate = ymdPriorMonth settings.viewDate },
            expect = Http.expectWhatever ReloadData
          })
        Nothing -> (model, Cmd.none)
    (CalendarPage page, NextMonth) ->
      case getActiveSettings model of
        Just active ->
          let settings = active.settings in
          (model, Http.post
          {
            url = "/sched/update_settings",
            body = Http.jsonBody
              <| settingsEncoder { settings | 
                viewDate = ymdNextMonth settings.viewDate },
            expect = Http.expectWhatever ReloadData
          })
        Nothing -> (model, Cmd.none)
    (_, _) ->
      (model, Cmd.none)

-- VIEW
toDocument : Element Message -> Browser.Document Message
toDocument rootElement =
  {
    title = "Scheduler",
    body = 
    [
      layoutWith
      {
        options = 
        [
          -- focusStyle
          -- {
          --   borderColor = Nothing,
          --   backgroundColor = Nothing,
          --   shadow = Nothing
          -- }
        ]
      }
      [
        Font.family
        [
          Font.typeface "Open Sans",
          Font.sansSerif
        ]
      ] 
      rootElement
    ]
  }

selectViewButton =
  Input.button
  [
    defaultShadow,
    padding 5
  ]
  {
    onPress = Just OpenViewSelect,
    label = text "Select View"
  }

editViewButton =
  Input.button
  [
    defaultShadow,
    padding 5
  ]
  {
    onPress = Just OpenViewEdit,
    label = text "Edit View"
  }

viewLogoutButton =
  Input.button
  [
    defaultShadow,
    padding 5
  ]
  {
    onPress = Just Logout,
    label = text "Log out"
  }

viewCalendarFooter : Element Message
viewCalendarFooter =
  row
    [
      height (px 32),
      width fill,
      Border.solid,
      Border.color (rgb 1 1 1),
      Border.width 1,
      spacing 15
    ]
    [
      selectViewButton, 
      editViewButton,
      viewLogoutButton
    ]

viewLogin : Model -> Element Message
viewLogin model =
  case model.page of
    LoginPage page ->
      column 
        [
          padding 100, 
          width fill,
          BG.color (rgb 0.85 0.9 0.95),
          centerY
        ] 
        [
          column 
            [
              centerX
            ]
            [
              el 
                [
                  alignRight,
                  width (px 300),
                  padding 15
                ] (el [centerX] (text "Login to Scheduler")),
              column
                [
                  spacing 15
                ]
                [
                  Input.username
                    [
                      Input.focusedOnLoad,
                      alignRight,
                      width (px 300),
                      padding 15,
                      spacing 15
                    ]
                    {
                      label = Input.labelLeft [] (text "Email"),
                      onChange = UpdateEmail,
                      placeholder = Just (Input.placeholder [] (text "you@something.com")),
                      text = page.loginInfo.email
                    },
                  Input.currentPassword
                    [
                      alignRight,
                      width (px 300),
                      padding 15,
                      spacing 15
                    ]
                    {
                      onChange = UpdatePassword,
                      text = page.loginInfo.password,
                      label = Input.labelLeft [] (text "Password"),
                      placeholder = Just (Input.placeholder [] (text "Password")),
                      show = False
                    }
                ],
              row
                [
                  alignRight,
                  width (px 300),
                  paddingXY 0 15
                ]
                [
                  Input.button 
                    [ 
                      alignLeft,
                      BG.color (rgb 0.25 0.8 0.25),
                      defaultShadow,
                      padding 10
                    ]
                    {
                      label = text "Login",
                      onPress = Just LoginRequest
                    }
                ]
            ]
        ]
    _ -> text "Error: viewing login while on another page"  

foldDaysLeftInYear : YearMonthDay -> Int -> Int
foldDaysLeftInYear ymd soFar =
  let
    thisMonth = daysLeftInMonth ymd
    newTotal = soFar + thisMonth
  in 
    if ymd.month < 12 then
      foldDaysLeftInYear
        (YearMonthDay ymd.year (ymd.month + 1) 1)
        newTotal
    else
      newTotal

ymFromYmd ymd =
  YearMonth ymd.year ymd.month

daysLeftInMonth : YearMonthDay -> Int
daysLeftInMonth ymd = (daysInMonth (ymFromYmd ymd) + 1) - ymd.day

foldAddDaysBetween : YearMonthDay -> YearMonthDay -> Int -> Int
foldAddDaysBetween day1 day2 soFar =
  if (day1.year < day2.year) then 
    foldAddDaysBetween 
      (YearMonthDay (day1.year + 1) 1 1) 
      day2 
      ((foldDaysLeftInYear day1 0) + soFar)
  else if (day1.month < day2.month) then
    foldAddDaysBetween
      (YearMonthDay day1.year (day1.month + 1) 1)
      day2
      (daysLeftInMonth day1 + soFar)
  else if (day1.day < day2.day) then
    soFar + (day2.day - day1.day)
  else soFar

daysApart : YearMonthDay -> YearMonthDay -> Maybe Int
daysApart day1 day2 =
  case compareDays (Just day1) (Just day2) of
    Past ->
      Just (foldAddDaysBetween day1 day2 0)
    Today -> Just 0
    Future ->
      Just (foldAddDaysBetween day2 day1 0)
    _ -> Nothing

dayRepeatMatch startDay matchDay everyX =
  case daysApart startDay matchDay of
    Just apart ->
      if modBy everyX apart == 0 then True
      else False
    Nothing -> False

weekRepeatMatch startDay matchDay everyX =
  dayRepeatMatch startDay matchDay (everyX * 7)

exactShiftMatch : YearMonthDay -> YearMonthDay -> Bool
exactShiftMatch day shift =
  shift.year == day.year 
  && shift.month == day.month 
  && shift.day == day.day

shiftMatch : YearMonthDay -> Shift -> Bool
shiftMatch ymd shift =
  let shiftYMD = YearMonthDay shift.year shift.month shift.day in
  case shift.repeat of
    NeverRepeat ->
      exactShiftMatch ymd shiftYMD
    EveryWeek ->
      weekRepeatMatch shiftYMD ymd shift.everyX
    EveryDay ->
      dayRepeatMatch shiftYMD ymd shift.everyX

ymdFromShift : Shift -> YearMonthDay
ymdFromShift shift =
  YearMonthDay
    shift.year
    shift.month
    shift.day

shiftCompare : Shift -> Shift -> Order
shiftCompare s1 s2 =
  case dayCompare (ymdFromShift s1) (ymdFromShift s2) of
    LT -> LT
    EQ -> shiftHourCompare s1 s2
    GT -> GT

shiftHourCompare : Shift -> Shift -> Order
shiftHourCompare s1 s2 =
  case compare s1.hour s2.hour of
        LT -> LT
        EQ -> compare s1.minute s2.minute
        GT -> GT

filterByYearMonthDay : YearMonthDay -> 
  List Shift -> List Shift
filterByYearMonthDay day shifts =
    List.filter (shiftMatch day) shifts
    |> List.sortWith shiftHourCompare

endsFromStartDur : Float -> Float -> (Float, Float)
endsFromStartDur start duration =
  let end = start + duration in
  (start, end)

formatHour12 : Float -> String
formatHour12 floatTime =
  let 
    rawHour = floor floatTime
    hour24 = modBy 24 rawHour
    hour12 = modBy 12 rawHour
  in 
  if hour24 > 12 then
        (String.fromInt hour12) ++ "p"
      else if hour24 == 12 then
        (String.fromInt 12) ++ "p"
      else
        (String.fromInt hour12) ++ "a"

formatHour24 : Float -> String
formatHour24 floatTime =
  let 
    rawHour = floor floatTime
    hour24 = modBy 24 rawHour
  in String.fromInt hour24

formatHours : Settings -> Float -> Float -> Element Message
formatHours 
  settings 
  start
  duration =
  case settings.hourFormat of
    Hour12 -> 
      let (_, end) = endsFromStartDur start duration
      in (text (formatHour12 start ++ "-" ++ formatHour12 end))
    Hour24 -> 
      let (_, end) = endsFromStartDur start duration
      in (text (formatHour24 start ++ "-" ++ formatHour24 end))


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

ymdToString : YearMonthDay -> String
ymdToString ymd =
  let 
    yearStr = String.fromInt ymd.year
    monthStr = monthNumToString ymd.month
    dayStr = String.fromInt ymd.day
    weekdayStr = weekdayNumToString (toWeekday ymd)
  in
    -- Weekday, Month Day, Year
    weekdayStr ++ ", "
    ++ monthStr ++ " "
    ++ dayStr ++ ", "
    ++ yearStr

getEmployee : List Employee -> Int -> Maybe Employee
getEmployee employees id =
  List.filter (\emp -> emp.id == id) employees
  |> List.head

getViewEmployees : List Employee -> List Int -> List Employee
getViewEmployees employees viewEmployees =
  List.filterMap
    (\id -> getEmployee employees id)
    viewEmployees

formatLastName : Settings -> String -> String
formatLastName settings name =
  case settings.lastNameStyle of
    FullName -> name
    FirstInitial -> String.left 1 name
    Hidden -> ""

shiftElement : 
  Model
  -> Settings 
  -> List Employee
  -> Shift 
  -> Element Message
shiftElement model settings employees shift =
  case getEmployee employees shift.employeeID of
    Just employee ->
      Input.button
      [
        fillX,
        clipX
      ]
      {
        onPress = Just (OpenShiftModal Nothing (Just shift)),
        label = 
          row
          ([
            Font.size 14,
            paddingXY 0 2,
            Border.width 2,
            Border.rounded 3,
            width fill
          ] ++ case getEmployeeSettings model shift.employeeID of
            Just perEmployee -> 
              let
                colorPair = employeeColor perEmployee.color
              in
                [
                  Border.color <| fromRgb colorPair.dark,
                  BG.color <| fromRgb colorPair.light
                ] 
            Nothing -> 
              [
                Border.color <| rgb 0.5 0.5 0.5,
                BG.color <| rgb 0.8 0.8 0.8
              ]) 
          [
            el [padding 1] <|
            text 
              (employee.name.first
              ++ (if settings.lastNameStyle == Hidden then "" else " ")
              ++ formatLastName settings employee.name.last
              ++ ": "),
            let 
              floatBegin = hourMinuteToFloat shift.hour shift.minute
              floatDuration = hourMinuteToFloat shift.hours shift.minutes
            in
              (formatHours settings floatBegin floatDuration)
          ]
      }
      
    Nothing -> none

dayStyle : Maybe YearMonthDay -> DayState -> List (Attribute Message)
dayStyle ymdMaybe dayState = 
  ([
    width fill,
    height fill,
    clipX,
    clipY,
    scrollbarX,
    Border.widthEach {bottom = 0, left = 1, right = 0, top = 0},
    Border.color (rgb 0.2 0.2 0.2)
  ] ++
  case dayState of
    Today -> 
      [
        BG.color (rgb 0.99 1 0.99),
        Border.innerGlow lightGreen 3
      ]
    Future -> []
    Past -> 
      [
        -- Border.innerGlow grey 3,
        BG.color lightGrey
      ]
    None -> [])

shiftColumn : 
  Model ->
  Settings -> 
  YearMonthDay -> 
  List Shift -> 
  List Employee -> 
  Element Message
shiftColumn model settings day shifts employees =
  column 
  [
    fillX
  ] 
  (
    List.map 
      (shiftElement model settings employees)
      (filterByYearMonthDay day shifts)
  )

type ShiftRepeat =
  NeverRepeat |
  EveryWeek |
  EveryDay

type alias ShiftModalData =
  {
    priorShift : Maybe Shift,
    employee : Maybe Employee,
    employeeSearch : String,
    employeeMatches : List Employee,
    ymd : YearMonthDay,
    start : Float,
    duration : Float,
    shiftRepeat : ShiftRepeat,
    everyX : String
  }

type alias ViewSelectData =
  {
  }

type alias ViewEditData =
  {
    settings : Settings,
    changed : Bool,
    colorSelect : Maybe Employee
  }

defaultViewEdit : Settings -> ViewEditData
defaultViewEdit settings =
  ViewEditData settings False Nothing

chooseSuffix : Float -> String
chooseSuffix f =
  let 
    h24 = modBy 24 (floor f)
  in
    if h24 >= 12 then "PM" else "AM"

floatToQuarterHour : Float -> Int
floatToQuarterHour f =
  let
    fractional = f - (toFloat (truncate f))
    minutes = fractional * 60
  in
    round (minutes / 15) * 15

floatToMinuteString : Float -> String
floatToMinuteString f =
  let
    nearestQuarter = floatToQuarterHour f
  in
    case nearestQuarter of
      0 -> "00"
      _ -> String.fromInt nearestQuarter

floatToHour : Float -> Int
floatToHour f =
  modBy 24 (floor f)

floatToTimeString : Float -> HourFormat -> String
floatToTimeString f hourFormat =
  case hourFormat of
    Hour12 ->
      let 
        suffix = chooseSuffix f
        hour = floor f |> modBy 12
        hourFixed = 
          if hour == 0 then 12 else hour
        hourStr = if hourFixed < 10 then "0" ++ (String.fromInt hourFixed)
          else String.fromInt hourFixed
        minutesStr = floatToMinuteString f
      in
        hourStr ++ ":" ++ minutesStr ++ suffix
    Hour24 ->
      let
        hour = floatToHour f
        hourStr = if hour < 10 then "0" ++ (String.fromInt hour)
          else String.fromInt hour
        minutesStr = floatToMinuteString f
      in
        hourStr ++ ":" ++ minutesStr

floatToDuration : Float -> String
floatToDuration f =
  let
      hours = floor f
      hoursStr = if hours < 10 then "0" ++ (String.fromInt hours)
        else String.fromInt hours
      minutesStr = floatToMinuteString f
  in
    hoursStr ++ ":" ++ minutesStr
  


employeeAutofillElement : List Employee -> List (Input.Option (Employee) Message)
employeeAutofillElement employeeList =
  (List.map 
    (\employee -> 
      Input.optionWith
      employee <| 
      (\state ->
        el 
          (
            List.append
            [
              padding 5,
              defaultShadow
            ]
            (
              case state of
                Input.Selected ->
                  [
                    BG.color white,
                    Border.color black,
                    Border.width 1
                  ]
                _ -> 
                  [
                    BG.color modalColor,
                    Border.color borderColor
                  ]
            )
          )
          (text (nameToString employee.name))
      ) 
    ) 
    employeeList)

modalColor = rgb 0.9 0.9 0.9

defaultShadow = 
  Border.shadow 
    {
      offset = (3, 3),
      size = 3,
      blur = 6,
      color = (rgba 0 0 0 0.25)
    }

black = rgb 0 0 0
grey = rgb 0.5 0.5 0.5
white = rgb 1 1 1
lightGreen = rgb 0.65 0.85 0.65
lightGrey = rgb 0.85 0.85 0.85
borderColor = rgb 0.7 0.7 0.7

defaultBorder =
  [
    Border.solid,
    Border.color borderColor,
    Border.width 1,
    Border.rounded 3
  ]

headerFontSize = Font.size 30
    
shiftModalElement : Model -> ShiftModalData -> Element Message
shiftModalElement model shiftData =
  case (model.page, getActiveSettings model) of
    (CalendarPage page, Just activeSettings) ->
      let settings = activeSettings.settings in
      column
        [
          centerX,
          centerY,
          BG.color modalColor,
          padding 15,
          defaultShadow,
          spacingXY 0 15
        ]
        [
          -- Shift edit header text
          el
            [
              fillX,
              fillY,
              headerFontSize,
              BG.color white,
              padding 15
            ]
            (el 
              [
                centerX,
                centerY
              ] 
              (case shiftData.priorShift of
                Just prior -> text "Edit shift:"
                Nothing -> text "Create shift:")
            ),
          -- Date display
          el
            [
              centerX,
              centerY
            ]
            (text (ymdToString shiftData.ymd)),
            
          -- Employee search/select
          column
            [
              spacing 15,
              paddingXY 0 15
            ]
            [
              Input.search 
              [
                fillX,
                defaultShadow,
                centerX,
                htmlAttribute (HtmlAttr.id "employeeSearch"),
                onRight 
                  (case shiftData.employee of
                    Just employee ->
                        el 
                        ([fillX, fillY, paddingXY 10 0]) 
                        (el 
                          [
                            alignBottom, 
                            BG.color white, 
                            Border.color lightGreen,
                            Border.width 2,
                            Border.rounded 3,
                            padding 12
                          ]
                          <| text 
                          <| nameToString employee.name)
                    Nothing -> el [fillX] none
                    )
              ]
              {
                onChange = ShiftEmployeeSearch,
                text = shiftData.employeeSearch,
                placeholder = Nothing,
                label = Input.labelAbove [centerX, padding 2] (text "Find employee: ")
              },
              
              Input.radio
                ([
                  clipY,
                  scrollbarY,
                  height (px 150),
                  fillX
                ] ++ defaultBorder)
                {
                  onChange = ChooseShiftEmployee,
                  selected = shiftData.employee,
                  label = Input.labelHidden ("Employees"),
                  options = employeeAutofillElement 
                    shiftData.employeeMatches
                }
            ],

          -- Shift start slider
          column
          (
            [
              fillX
            ] ++
            defaultBorder
          )
          [
            row
              []
              [
                text "Start at: ",
                el
                  [
                    BG.color white,
                    Border.solid,
                    Border.color borderColor,
                    Border.width 1,
                    Border.rounded 3,
                    padding 3,
                    Font.family
                      [
                        Font.monospace
                      ]
                  ]
                  (
                    text
                      (
                        floatToTimeString 
                        shiftData.start 
                        settings.hourFormat
                      )
                  )
              ],
              Input.slider
              [
                -- Slider BG
                behindContent
                  (
                    el
                    [
                      BG.color white,
                      centerY,
                      fillX,
                      height (px 5)
                    ]
                    none
                  )

              ]
              {
                onChange = UpdateShiftStart,
                label = 
                  Input.labelHidden "Start Time", 
                min = 0,
                max = 23.75,
                value = shiftData.start,
                step = Just 0.25,
                thumb = Input.defaultThumb
              }
          ],

          -- Shift duration slider
          column
          (
            [
              fillX
            ] ++
            defaultBorder
          )
          [
            -- Label for duration slider
            row
              [
                fillX
              ]
              [
                text "Duration: ",
                el
                  ([
                    BG.color white,
                    padding 3,
                    Font.family
                      [
                        Font.monospace
                      ]
                  ] ++ defaultBorder)
                  (
                    text
                      (
                        floatToDuration 
                        shiftData.duration 
                      )
                  ),
                text " Ends: ",
                el
                  ([
                    BG.color white,
                    padding 3,
                    Font.family
                      [
                        Font.monospace
                      ]
                  ] ++ defaultBorder)
                  (
                    text
                      (
                        floatToTimeString
                        (shiftData.start +
                        shiftData.duration) 
                        settings.hourFormat
                      )
                  )
              ],
              Input.slider
              [
                -- Slider BG
                behindContent
                  (
                    el
                    [
                      BG.color white,
                      centerY,
                      fillX,
                      height (px 5)
                    ]
                    none
                  )

              ]
              {
                onChange = UpdateShiftDuration,
                label = 
                  Input.labelHidden "Shift Duration", 
                min = 0,
                max = 16,
                value = shiftData.duration,
                step = Just 0.25,
                thumb = Input.defaultThumb
              }
          ],

          -- Repeat controls
          row 
            (
            [
              width shrink,
              spacing 5
            ] ++ defaultBorder
            )
          [
            Input.radio
            [
              BG.color white,
              padding 5
            ]
            {
              onChange = UpdateShiftRepeat,
              selected = Just shiftData.shiftRepeat,
              label = Input.labelAbove 
                [BG.color lightGrey, fillX, padding 5] 
                (el [centerX] (text "Repeat:")),
              options =
                [
                  Input.option NeverRepeat (text "Never"),
                  Input.option EveryWeek (text "Weekly"),
                  Input.option EveryDay (text "Daily")
                ]
            },
            Input.text
            [
              width (px 50),
              padding 5,
              alignTop
            ]
            {
              onChange = UpdateShiftRepeatRate,
              text = shiftData.everyX,
              placeholder = Nothing,
              label = Input.labelAbove
                [
                  BG.color lightGrey, 
                  padding 5]
                (text "Every:")
            }
          ],
          
          -- Navigation buttons
          row 
          [
            spacing 10,
            padding 5,
            fillX
          ]
          [
            case shiftData.priorShift of
              Just prior ->
                Input.button
                  [
                    BG.color (green),
                    padding 5,
                    defaultShadow
                  ]
                  {
                    onPress = case shiftFromModal shiftData of 
                      Just updatedShift -> 
                        Just (UpdateShiftRequest updatedShift)
                      Nothing -> Nothing,
                    label = text "Update"
                  }
              Nothing ->
                Input.button
                [
                  BG.color (green),
                  padding 5,
                  defaultShadow
                ]
                {
                  onPress = Just (AddShift),
                  label = text "Save"
                },
            Input.button
            [
              BG.color (red),
              padding 5,
              defaultShadow,
              alignRight
            ]
            {
              onPress = Just CloseShiftModal,
              label = text "Back"
            }
          ]
        ]
    _ -> text "Error: viewing calendar from another page"
  
dayOfMonthElement : YearMonthDay -> Element Message
dayOfMonthElement day =
  el 
  [
    Font.size 16
  ] 
  (
    text (String.fromInt day.day)
  )

addShiftElement : YearMonthDay -> Element Message
addShiftElement day =
  Input.button
  [
    BG.color lightGreen,
    Border.rounded 5,
    Font.size 16,
    paddingEach { top = 0, bottom = 0, right = 2, left = 1}
  ]
  {
    onPress = Just (OpenShiftModal (Just day) Nothing),
    label = 
      el [moveUp 1]
        (text "+")
  }

dayCompare : YearMonthDay -> YearMonthDay -> Order
dayCompare d1 d2 =
  case compare d1.year d2.year of
    LT -> LT
    EQ -> case compare d1.month d2.month of
      LT -> LT
      EQ -> compare d1.day d2.day 
      GT -> GT
    GT -> GT

compareDays maybe1 maybe2 =
  case (maybe1, maybe2) of
    (Just d1, Just d2) -> 
      case dayCompare d1 d2 of
        LT -> Past
        EQ -> Today
        GT -> Future
    (_, _) -> None

type DayState =
  None |
  Past |
  Today |
  Future

dayElement : 
  Model
  -> Settings 
  -> List Shift
  -> List Employee
  -> Maybe YearMonthDay
  -> Maybe YearMonthDay
  -> Element Message
dayElement model settings shifts employees focusDay maybeYMD =
  let dayState = (compareDays maybeYMD focusDay) in
  case maybeYMD of
    Just day -> 
      el
      (dayStyle maybeYMD dayState)
      (
        column 
        [
          fillX,
          paddingXY 5 0
        ]
        [
          row
          [
            padding 5
          ]
          [
            dayOfMonthElement day,
            addShiftElement day
          ],
          shiftColumn model settings day shifts employees
        ]
      )
      
    Nothing -> 
      el 
      (dayStyle maybeYMD dayState)
      <| column [fillX][]

monthRowElement : 
  Model 
  -> Settings 
  -> Maybe YearMonthDay
  -> List Shift
  -> List Employee
  -> Row
  -> Element Message
monthRowElement model settings focusDay shifts employees rowElement =
  row 
    [
      height fill,
      width fill,
      spacing 0,
      Border.widthEach {top = 0, bottom = 1, right = 0, left = 0}
    ] 
    (
      Array.toList 
      (
        Array.map 
        (dayElement model settings shifts employees focusDay) 
        rowElement
      )
    )
searchRadio :
  String ->
  String ->
  String ->
  (String -> Message) ->
  Element Message ->
  (a -> Message) ->
  Maybe a ->
  String ->
  List (Input.Option a Message) ->
  Element Message
searchRadio
  searchID 
  searchLabel 
  searchText 
  searchChangeMsg 
  confirmed 
  radioChangeMsg 
  radioSelected
  radioLabel 
  radioOptions =
  column
  [
    spacing 15,
    paddingXY 0 15
  ]
  [
    Input.search 
    [
      fillX,
      defaultShadow,
      centerX,
      htmlAttribute (HtmlAttr.id searchID),
      onRight confirmed
    ]
    {
      onChange = searchChangeMsg,
      text = searchText,
      placeholder = Nothing,
      label = 
        Input.labelAbove 
        [centerX, padding 2] 
        (text searchLabel)
    },
    
    Input.radio
      ([
        clipY,
        scrollbarY,
        height (px 150),
        fillX
      ] ++ defaultBorder)
      {
        onChange = radioChangeMsg,
        selected = radioSelected,
        label = Input.labelHidden radioLabel,
        options = radioOptions
      }
  ]

settingsToOption : CombinedSettings -> Input.Option Int Message
settingsToOption combined =
  let settings = combined.settings in
  Input.option
  settings.id
  (el [fillX] <| 
    el
    ([
      defaultShadow,
      BG.color lightGrey,
      centerX,
      padding 5
    ] ++ defaultBorder)
    <| text settings.name)

colorDisplay : EmployeeColor -> Element Message
colorDisplay c =
  let 
    pair = employeeColor c
    lightRgb = pair.light
    darkRgb = pair.dark
    light = fromRgb lightRgb
    dark = fromRgb darkRgb
  in
  el [padding 2] <|
  el 
  [
    width <| px 20,
    height <| px 20,
    BG.color light,
    Border.color dark,
    Border.width 2,
    Border.rounded 10
  ] none

colorSelectOpenButton : Employee -> EmployeeColor -> Element Message
colorSelectOpenButton employee color =
  Input.button []
  {
    onPress = Just <| OpenEmployeeColorSelector employee,
    label = colorDisplay color
  }

colorSelector : Employee -> EmployeeColor -> Element Message
colorSelector employee color =
  Input.radioRow
  ([
    BG.color white,
    defaultShadow
  ] ++ defaultBorder)
  {
    onChange = ChooseEmployeeColor employee,
    selected = Just color,
    label = Input.labelHidden "Employee color",
    options = 
      let 
        colorOpt = 
          (
            \c -> 
              Input.optionWith c 
                (\o -> case o of
                  Input.Selected -> el defaultBorder <| colorDisplay c
                  _ -> colorDisplay c
                )
          ) 
      in
        [
          colorOpt Red,
          colorOpt LightRed,
          colorOpt Green,
          colorOpt LightGreen,
          colorOpt Blue,
          colorOpt LightBlue,
          colorOpt Yellow,
          colorOpt LightYellow,
          colorOpt Grey,
          colorOpt LightGrey,
          colorOpt Brown,
          colorOpt Black
        ]
  }

employeeToColorPicker : Employee -> EmployeeColor -> Bool -> Element Message
employeeToColorPicker employee color selectOpen =
  case selectOpen of
    True -> colorSelector employee color
    False -> colorSelectOpenButton employee color

employeeToCheckbox : CombinedSettings -> Employee -> Element Message
employeeToCheckbox combined employee =
  let 
    filtered = 
      List.filter
      (\i -> i == employee.id)
      combined.settings.viewEmployees
    first = List.head filtered
  in 
    Input.checkbox 
    ([] ++ defaultBorder)
    {
      onChange = EmployeeViewCheckbox employee.id,
      icon = Input.defaultCheckbox,
      checked = (case first of
        Just found -> True
        Nothing -> False),
      label = Input.labelRight [] 
        (text <| nameToString employee.name)
    }
  
basicButton : 
  List (Attribute Message) -> 
  Color -> 
  Maybe Message -> 
  String ->
  Element Message
basicButton attrs color onPress label =
  Input.button
  ([
    BG.color color,
    padding 5,
    defaultShadow
  ] ++ attrs)
  {
    onPress = onPress,
    label = text label
  }

selectViewElement : Model -> Element Message
selectViewElement model = 
  column
    ([
      centerX,
      centerY,
      BG.color lightGrey,
      defaultShadow,
      spacing 5
    ] ++ defaultBorder)
    [
      -- title text
      el 
        [
          fillX, 
          fillY,
          padding 10
        ] 
        <| el
          [
            centerX, 
            centerY, 
            BG.color white, 
            headerFontSize, 
            padding 15
          ]
        <| text "Views:",
      -- active view select
      el 
      [
        fillX,
        padding 10
      ] <|
      Input.radio [centerX]
        {
          onChange = ChooseActiveView,
          options = 
            List.map 
            settingsToOption 
            <| Maybe.withDefault [] model.settingsList,
          selected = model.activeSettings,
          label = 
            Input.labelAbove [fillX] 
            <| el [centerX] <| text "Select view:"
      },
      -- navigation
      row ([fillX, spacing 15] 
        ++ defaultBorder)
      [
        basicButton
          []
          yellow
          (Just DuplicateView)
          "Copy View",
        basicButton
          []
          green
          (Just CloseViewSelect)
          "Back"
      ]
    ]

yellow = rgb 0.7 0.7 0.2

editViewElement : Model -> ViewEditData -> Maybe CombinedSettings -> Maybe (List Employee) -> Element Message
editViewElement model editData maybeSettings employees =
  case maybeSettings of
    Just combined ->
      let settings = combined.settings in
        column
      ([
        centerX,
        centerY,
        BG.color lightGrey,
        padding 10,
        defaultShadow
      ] ++ defaultBorder)
        [
        -- header text
        el 
        [
          fillX, 
          headerFontSize, 
          padding 10, 
          BG.color white,
          alignTop
        ] <| el [centerX] <| text "Edit view",
        
        el [fillX]
        <| Input.text [centerX]
          {
            onChange = UpdateViewName,
            text = settings.name,
            placeholder = Nothing,
            label = Input.labelAbove [] <| text "View Name:"
          },

        -- View type, hour format, last name style
          row
        ([
          padding 10,
          alignTop
        ] ++ defaultBorder)
        [
          Input.radio
          ([
            alignTop
          ] ++ defaultBorder)
          {
            onChange = UpdateViewType,
            options = 
            [
              Input.option MonthView (text "Month view"),
              Input.option WeekView (text "Week view"),
              Input.option DayView (text "Day view")
            ],
            selected = Just settings.viewType,
            label = Input.labelAbove [] <| text "View Type:"
          },
          Input.radio
          ([
            alignTop
          ] ++ defaultBorder)
          {
            onChange = UpdateHourFormat,
            options =
          [
              Input.option Hour12 <| text "12-hour time",
              Input.option Hour24 <| text "24-hour time"
            ],
            selected = Just settings.hourFormat,
            label = Input.labelAbove [] <| text "Hour Format:"
          },
          Input.radio
          ([
            alignTop
          ] ++ defaultBorder)
          {
            onChange = UpdateLastNameStyle,
            options =
          [
              Input.option FullName <| text "Full name",
              Input.option FirstInitial <| text "First initial",
              Input.option Hidden <| text "Hidden"
            ],
            selected = Just settings.lastNameStyle,
            label = Input.labelAbove [] <| text "Last name style:"
          }
        ],
              
        -- employee selection
          column
          ([
            fillX,
            spacing 5, 
            padding 10, 
            BG.color white
          ] ++ defaultBorder)
          <| List.map 
          (
            \e -> 
              let
                maybePerEmployee = getEmployeeSettings model e.id
                color = case maybePerEmployee of
                  Just perEmployee -> perEmployee.color
                  Nothing -> Green
                selectOpen = case editData.colorSelect of
                  Just colorEmp -> colorEmp.id == e.id
                  Nothing -> False
              in
                row [fillX, spacingXY 30 0] 
                [
                  employeeToCheckbox combined e,
                  employeeToColorPicker e color selectOpen
                ]
          )
          (Maybe.withDefault [] employees),
        
          -- Save, Save As, Cancel
        el ([fillX] ++ defaultBorder) <|
          row
        [centerX, spacing 15]
          [
            basicButton
              []
            yellow
            (Just CloseViewEdit)
            "Back"
        ]
      ]
    Nothing -> 
      el ([fillX] ++ defaultBorder) <|
      row
      [centerX, spacing 15]
      [
            basicButton
              []
          yellow
              (Just CloseViewEdit)
          "Back"
        ]

green = rgb 0.2 0.9 0.2
red = rgb 0.9 0.2 0.2

viewMonthRows :
  Model ->
  Month ->
  Maybe YearMonthDay ->
  Settings ->
  List Shift ->
  List Employee ->
  Element Message
viewMonthRows model month focusDay settings shifts employees =
  column
  [
    width fill,
    height fill,
    spacing 1
  ] 
  (Array.toList 
    (Array.map 
      (monthRowElement 
      model
      settings 
      focusDay
      shifts 
      employees)
    month))

fillX = width fill
fillY = height fill

borderR = Border.widthEach 
  { top = 0, bottom = 0, left = 0, right = 1 }

borderL = Border.widthEach 
  { top = 0, bottom = 0, left = 1, right = 0 }

viewMonth :
  Model ->
  Maybe YearMonthDay ->
  Month ->
  Settings ->
  List Shift ->
  List Employee ->
  Element Message
viewMonth model ymdMaybe month settings shifts employees =
  case ymdMaybe of
    Just ymd ->
      column
      [
        fillX,
        fillY
      ]
      [
        row
          [
          fillX,
          spaceEvenly
          ]
        [

        Input.button [paddingXY 50 0]
        {
          onPress = Just PriorMonth,
          label = text "<<--"
        },
        el [] <| text (monthNumToString settings.viewDate.month),
        Input.button [paddingXY 50 0]
        {
          onPress = Just NextMonth,
          label = text "-->>"
        }
        ],
        row
        [
          fillX, 
          height shrink,
          Border.widthEach 
            {top = 1, bottom = 1, left = 0, right = 0}
        ]
        [
          el [fillX, borderL] (el [centerX] (text "Sunday")),
          el [fillX, borderL] (el [centerX] (text "Monday")),
          el [fillX, borderL] (el [centerX] (text "Tuesday")),
          el [fillX, borderL] (el [centerX] (text "Wednesday")),
          el [fillX, borderL] (el [centerX] (text "Thursday")),
          el [fillX, borderL] (el [centerX] (text "Friday")),
          el [fillX, borderL] (el [centerX] (text "Saturday"))
        ],
        viewMonthRows model month ymdMaybe settings shifts employees
      ]
    Nothing -> text "Loading..."

viewModal : Model -> Element Message
viewModal model =
  case model.page of
    CalendarPage page ->
      case page.modal of
        NoModal -> none
        ShiftModal shiftModalData ->
          shiftModalElement model shiftModalData
        ViewSelectModal -> 
          selectViewElement model 
        ViewEditModal editData ->
          editViewElement model editData (getActiveSettings model) model.employees
    _ -> text "Error: viewing modal from wrong page"

viewCalendar : Model -> Element Message
viewCalendar model =
  case 
  (
    (model.settingsList, getActiveSettings model),
    (model.employees, model.shifts),
    (model.here, model.posixNow)
  ) of
    ((Just settingsList, Just activeSettings), 
      (Just employees, Just shifts),
      (Just here, Just now)) ->
      let today = getTime now here in
      case activeSettings.settings.viewType of
        MonthView ->
          let 
            viewDay = activeSettings.settings.viewDate
            month = makeGridFromMonth 
              (YearMonth viewDay.year viewDay.month)
          in
            column
            [
              width fill,
              height fill,
              inFront (viewModal model)
            ]
            [
              viewMonth 
                model 
                (Just today) 
                month 
                activeSettings.settings 
                shifts 
                (List.filterMap 
                  (\id -> getEmployee employees id)
                  activeSettings.settings.viewEmployees),
              viewCalendarFooter
            ]
        WeekView ->
          column [fillX, fillY, inFront (viewModal model)]
          [viewCalendarFooter]
        DayView ->
          column [fillX, fillY, inFront (viewModal model)]
          [viewCalendarFooter]
    _ -> text "Loading..."

view : Model -> Browser.Document Message
view model =
  case model.page of
    LoginPage _ -> toDocument (viewLogin model)
    CalendarPage _ -> toDocument (viewCalendar model)