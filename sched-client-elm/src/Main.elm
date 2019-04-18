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
    viewType : ViewType,
    hourFormat : HourFormat,
    lastNameStyle : LastNameStyle,
    viewDate : YearMonthDay,
    viewEmployees : List Int
  }

type alias Employees =
  {
    employees : List Employee
  }

type alias Shifts =
  {
    shifts : List Shift
  }


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

type Page =
  LoginPage |
  CalendarPage

type CalendarModal =
  NoModal |
  SettingsModal |
  ShiftEditorModal ShiftModalData

type alias Model =
  {
    navkey : Nav.Key,
    settingsList : List Settings,
    activeSettings : Settings,
    page : Page,
    login_info : LoginInfo,
    email_state : InputState,
    password_state : InputState,
    button_state : InputState,
    user : Maybe User,
    employees : List Employee,
    employeeShifts : Dict Int (List Shift),
    loaded : Dict Int Bool,
    hover : Maybe HoverData,
    today : Maybe YearMonthDay,
    calendarModal : CalendarModal
  }

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

type alias YearMonthDay =
  {
    year : Int,
    month : Int,
    day : Int
  }

withNow : (Time.Posix -> Task.Task () a) -> (Task.Task () a)
withNow timeFunc =
  Time.now |> Task.andThen timeFunc

ymdNow =
  Time.now |> Task.andThen 
  (\time -> 
    Time.here 
    |> Task.andThen 
    (\zone -> 
      Task.succeed 
        (YearMonthDay 
        (Time.toYear zone time) 
        (monthToNum (Time.toMonth zone time))
        (Time.toDay zone time))
    )
  )

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

newSettingsEncoder : Settings -> E.Value
newSettingsEncoder settings =
  E.object
    [
      ("user_id", E.int settings.userID),
      ("view_type", viewTypeEncoder settings.viewType),
      ("hour_format", hourFormatEncoder settings.hourFormat),
      ("last_name_style", lastNameStyleEncoder settings.lastNameStyle),
      ("view_year", E.int settings.viewDate.year),
      ("view_month", E.int settings.viewDate.month),
      ("view_day", E.int settings.viewDate.day),
      ("viewEmployees", E.list E.int settings.viewEmployees)
    ]


viewYMDDecoder =
  D.succeed YearMonthDay
  |> JPipe.required "view_year" D.int
  |> JPipe.required "view_month" D.int
  |> JPipe.required "view_day" D.int

-- DESERIALIZATION
settingsDecoder : D.Decoder Settings
settingsDecoder =
  D.succeed Settings
  |> JPipe.required "id" D.int
  |> JPipe.required "user_id" D.int
  |> JPipe.required "view_type" viewTypeDecoder
  |> JPipe.required "hour_format" hourFormatDecoder
  |> JPipe.required "last_name_style" lastNameStyleDecoder
  |> JPipe.custom viewYMDDecoder
  |> JPipe.required "view_employees" (D.list D.int)

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

employeesQueryDecoder : D.Decoder Employees
employeesQueryDecoder =
  D.succeed Employees
  |> JPipe.requiredAt ["employees"] (D.list employeeDecoder)

shiftsQueryDecoder : D.Decoder Shifts
shiftsQueryDecoder =
  D.succeed Shifts
  |> JPipe.requiredAt ["shifts"] (D.list shiftDecoder)

employeeDecoder : D.Decoder Employee
employeeDecoder =
  D.succeed Employee
  |> JPipe.required "id" D.int
  |> JPipe.requiredAt ["name"] nameDecoder
  |> JPipe.required "phone_number" (D.maybe D.string)

shiftDecoder : D.Decoder Shift
shiftDecoder =
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
    MonthView 
    Hour12 
    FirstInitial
    (YearMonthDay 2019 3 23)
    []

loadData =
  Task.perform ReceiveTime ymdNow

init : () -> Url.Url -> Nav.Key -> (Model, Cmd Message)
init _ url key =
  router 
    (
      Model 
        key
        []
        settingsDefault
        LoginPage
        (LoginInfo "" "")
        Normal
        Normal
        Normal
        Nothing
        []
        Dict.empty
        Dict.empty
        Nothing
        Nothing
        NoModal
    ) url

-- UPDATE
type Message =
-- General Messages
  NoOp |
  UrlChanged Url.Url |
  UrlRequest Browser.UrlRequest |
  Logout |
  LogoutResponse (Result Http.Error ()) |
  KeyDown (Maybe Keys) |
  FocusResult (Result Dom.Error ()) |
  ReceiveSettings (Result Http.Error Settings) |
  ReceiveSettingsList (Result Http.Error (List Settings)) |
-- Login Messages
  CreateUser |
  LoginRequest |
  LoginResponse (Result Http.Error ()) |
  UpdateEmail String |
  UpdatePassword String |
-- Calendar Messages
  OverShift (Employee, Shift) |
  LeaveShift |
  DayClick (Maybe YearMonthDay) |
  -- ShiftModal Messages
  OpenShiftModal YearMonthDay |
  AddShift ShiftModalData |
  CloseShiftModal |
  ShiftEmployeeSearch String |
  ChooseShiftEmployee Employee |
  UpdateShiftStart Float |
  UpdateShiftDuration Float |
  -- SettingsModal Messages
  OpenSettingsModal |
  SaveSettings |
  CloseSettingsModal |
-- Loading Messages
  ReceiveEmployees (Result Http.Error (Employees)) |
  ReceiveShifts Employee (Result Http.Error (Shifts)) |
  ReceiveTime YearMonthDay |
  DoneLoading

loginRequest : LoginInfo -> (Cmd Message)
loginRequest loginInfo =
  Http.post
    {
      url = UB.absolute ["sched", "login_request"][],
      body = Http.jsonBody (encodeLoginInfo loginInfo),
      expect = Http.expectWhatever LoginResponse
    }

createUser : LoginInfo -> (Cmd Message)
createUser loginInfo =
  Http.post
    {
      url = UB.absolute ["sched", "add_user"][],
      body = Http.jsonBody (encodeLoginInfo loginInfo),
      expect = Http.expectWhatever LoginResponse
    }

updateLoginButton : Model -> Model
updateLoginButton page =
  if page.email_state == Success && 
    page.password_state == Success
    then { page | button_state = Success }
    else { page | button_state = Normal }

nameToString : Name -> String
nameToString name =
  name.first ++ " " ++ name.last

tasksComplete : Model -> Bool
tasksComplete model =
  Dict.foldl (\k v b -> 
    case b of
      True ->
        case v of
          False -> False
          True -> True
      False -> False) True model.loaded

foldEmployeesIntoTasks : Employee -> Dict Int Bool -> Dict Int Bool
foldEmployeesIntoTasks employee inDict =
  Dict.insert employee.id False inDict

markTaskComplete : Int -> Model -> Model
markTaskComplete id model =
  { model | loaded = Dict.insert id True model.loaded }

setLoadTasks : List Employee -> Model -> Model
setLoadTasks employees model =
  let 
    loaded = List.foldl foldEmployeesIntoTasks Dict.empty employees
  in
    { model | loaded = loaded }

requestEmployees : Cmd Message
requestEmployees =
  Http.post 
  {
    url="/sched/get_employees",
    body=Http.emptyBody,
    expect=Http.expectJson ReceiveEmployees employeesQueryDecoder
  }

requestShifts : Employee -> Cmd Message
requestShifts emp =
  Http.post {
    url="/sched/get_shifts",
    body=Http.jsonBody (employeeEncoder emp),
    expect=Http.expectJson (ReceiveShifts emp) shiftsQueryDecoder
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

shiftEditorForDay day employeeList =
  ShiftModalData
    Nothing
    ""
    employeeList
    day
    8
    8
    NeverRepeat
    "1"

router : Model -> Url.Url -> (Model, Cmd Message)
router model url =
    case url.path of
      "/sched" -> 
        ({ model | page = CalendarPage }, loadData)
      "/sched/login" ->
        ({ model | page = LoginPage }, Cmd.none)
      "/sched/calendar" ->
        ({ model | page = CalendarPage }, loadData)
      _ ->
        ({ model | page = LoginPage }, Cmd.none)

update : Message -> Model -> (Model, Cmd Message)
update message model =
  case (model.page, message) of
    (_, UrlRequest request) ->
      case request of
        Browser.Internal url ->
          (model, Nav.pushUrl model.navkey (Url.toString url))
        _ -> (model, Cmd.none)
    (_, UrlChanged url) ->
      router model url
    (_, ReceiveTime ymd) ->
      ({ model | today = Just ymd }, requestEmployees)
    (LoginPage, CreateUser) ->
      (model, createUser model.login_info)
    (LoginPage, LoginRequest) ->
      (model, loginRequest model.login_info)
    (LoginPage, LoginResponse r) ->
      let updatedModel = { model | login_info = LoginInfo "" "" } in
      case r of
        Ok _ ->
          (updatedModel, 
            Nav.pushUrl 
              model.navkey
              "/sched/calendar"
          )
        Err _ -> (updatedModel, Cmd.none)
    (LoginPage, UpdateEmail email) ->
      let oldInfo = model.login_info in
        ({ model | login_info = 
          { oldInfo | email = email } }, Cmd.none)
    (LoginPage, UpdatePassword password) ->
      let oldInfo = model.login_info in
        ({ model | login_info =
          { oldInfo | password = password } }, Cmd.none)
    (_, ReceiveEmployees employeesResult) ->
      case employeesResult of
        Ok employees ->
          let 
            loadingModel = setLoadTasks employees.employees model
            sortedEmps = 
              List.sortWith 
              (\e1 e2 -> 
                compare (nameToString e1.name) (nameToString e2.name)) 
                employees.employees
          in
            ({ loadingModel | employees = sortedEmps }, 
            Cmd.batch (List.map requestShifts sortedEmps))
        Err e ->
          (model, Nav.pushUrl model.navkey "/sched/login")
    (_, ReceiveShifts employee shiftsResult) ->
      case shiftsResult of
        Ok shifts ->
          let
            markedModel = markTaskComplete employee.id model
          in
              
            if tasksComplete markedModel then
              ({ markedModel | employeeShifts = 
                  (Dict.insert 
                    employee.id
                    shifts.shifts
                    model.employeeShifts)}, 
                  Task.succeed DoneLoading 
                  |> Task.perform identity)
            else
              ({ markedModel | employeeShifts = 
                  (Dict.insert 
                    employee.id
                    shifts.shifts
                    model.employeeShifts)}, Cmd.none)
        Err e -> 
          (model, Cmd.none)
    (_, DoneLoading) -> (model, Cmd.none)
    (CalendarPage, OpenSettingsModal) ->
      case model.calendarModal of
        NoModal ->
          (
            {
              model | calendarModal = SettingsModal
            },
            Cmd.none
          )
        _ -> (model, Cmd.none)
    (CalendarPage, CloseSettingsModal) ->
      case model.calendarModal of
        SettingsModal ->
          (
            {
              model | calendarModal = NoModal
            },
            Cmd.none
          )
        _ -> (model, Cmd.none)
    (CalendarPage, OpenShiftModal day) ->
      case model.calendarModal of
        NoModal -> 
          (
            { model | calendarModal = 
              ShiftEditorModal 
                (shiftEditorForDay day model.employees) }, 
            Task.attempt 
            FocusResult
            (Dom.focus "employeeSearch")
          )
        _ -> (model, Cmd.none)
    (CalendarPage, CloseShiftModal) ->
      case model.calendarModal of
        ShiftEditorModal _ ->
          ({ model | calendarModal = NoModal }, Cmd.none)
        _ -> (model, Cmd.none)
    (CalendarPage, KeyDown maybeArrow) ->
      (model, Cmd.none)
    (CalendarPage, ShiftEmployeeSearch searchText) ->
      case model.calendarModal of
        ShiftEditorModal shiftModalData ->
          let newMatches = Fuzzy.filter
                      (\emp -> nameToString emp.name)
                      searchText
                      model.employees
          in
          let 
            updatedModel = 
              { 
                model | calendarModal = ShiftEditorModal 
                  { 
                    shiftModalData | 
                      employeeSearch = searchText,
                      employeeMatches = newMatches
                        
                  }
              } 
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
    (CalendarPage, ChooseShiftEmployee employee) ->
      case model.calendarModal of
        ShiftEditorModal shiftModalData ->
          (
              { model | calendarModal = ShiftEditorModal
                { shiftModalData | employee = Just employee }},
              Cmd.none
          )
        _ -> (model, Cmd.none)
    (CalendarPage, UpdateShiftStart f) ->
      case model.calendarModal of
        ShiftEditorModal shiftModalData ->
          (
            {
              model | calendarModal = ShiftEditorModal
              {
                shiftModalData | start = f
              }
            },
            Cmd.none
          )
        _ -> (model, Cmd.none)
    (CalendarPage, UpdateShiftDuration f) ->
      case model.calendarModal of
        ShiftEditorModal shiftModalData ->
          (
            {
              model | calendarModal = ShiftEditorModal
              {
                shiftModalData | duration = f
              }
            },
            Cmd.none
          )
        _ -> (model, Cmd.none)
    (_, Logout) ->
      (
        model, 
        Http.post
        {
          url = UB.absolute ["sched", "logout_request"] [],
          body = Http.emptyBody,
          expect = Http.expectWhatever LogoutResponse
        }
      )
    (_, LogoutResponse _) ->
      (model, Nav.pushUrl model.navkey "/sched/login")
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

viewSettingsToggle =
  Input.button
  [
    alignLeft
  ]
  {
    onPress = Just OpenSettingsModal,
    label = text "Settings"
  }

viewLogoutButton =
  Input.button
  [
    alignRight
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
      Border.width 1
    ]
    [
      viewSettingsToggle, 
      viewLogoutButton
    ]

viewLogin model =
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
                  text = model.login_info.email
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
                  text = model.login_info.password,
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

formatHours : Settings -> Int -> Int -> Element Message
formatHours settings start duration =
  case settings.hourFormat of
    Hour12 -> 
      let (_, end) = endsFromStartDur (start, duration)
      in (text (formatHour12 start ++ "-" ++ formatHour12 end))
    Hour24 -> 
      let (_, end) = endsFromStartDur (start, duration)
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

pairEmployeeShift : Settings 
  -> (Employee, List Shift) 
  -> List (Element Message)
pairEmployeeShift settings (employee, shifts) = 
  List.map (shiftElement settings employee) shifts

foldElementList : List (Element Message) -> List (Element Message) -> List (Element Message)
foldElementList nextList soFar =
  List.append soFar nextList

combineElementLists : List (List (Element Message)) -> List (Element Message)
combineElementLists lists =
  List.foldl foldElementList [] lists

formatLastName : Settings -> String -> String
formatLastName settings name =
  case settings.lastNameStyle of
    FullName -> name
    FirstInitial -> String.left 1 name
    Hidden -> ""

shiftElement : 
  Settings 
  -> Employee
  -> Shift 
  -> Element Message
shiftElement settings employee shift =
  row
    [
      Font.size 14,
      paddingXY 0 2,
      Border.color (rgb 1 0 0),
      BG.color (rgba 1 0 0 0.1),
      Border.width 2,
      Border.rounded 3,
      width fill
    ] 
    [
      text 
        (employee.name.first
        ++ " "
        ++ formatLastName settings employee.name.last
        ++ ": "),
      (formatHours settings shift.hour shift.hours)
    ]

dayStyle ymdMaybe dayState = 
  ([
    width fill,
    height fill,
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

shiftColumn settings day employeeShifts =
  column 
  [
    centerX,
    width fill
  ] 
  (
    combineElementLists 
    (
      List.map 
      (pairEmployeeShift settings)
      (mapShiftsToYearMonthDay day employeeShifts)
    )
  )

type ShiftRepeat =
  NeverRepeat |
  EveryWeek |
  EveryDay

type alias ShiftModalData =
  {
    employee : Maybe Employee,
    employeeSearch : String,
    employeeMatches : List Employee,
    ymd : YearMonthDay,
    start : Float,
    duration : Float,
    shiftRepeat : ShiftRepeat,
    everyX : String
  }

chooseSuffix : Float -> String
chooseSuffix f =
  let 
    h24 = modBy 24 (floor f)
  in
    if h24 >= 12 then "PM" else "AM"

floatFractionToMinutes : Float -> String
floatFractionToMinutes f =
  let
    fractional = f - (toFloat (truncate f))
    minutes = fractional * 60
    nearestQuarter = round (minutes / 15)
  in
    case nearestQuarter of
      0 -> "00"
      _ -> String.fromInt (nearestQuarter * 15)

floatToTime : Float -> HourFormat -> String
floatToTime f hourFormat =
  case hourFormat of
    Hour12 ->
      let 
        suffix = chooseSuffix f
        hour = floor f |> modBy 12
        hourFixed = 
          if hour == 0 then 12 else hour
        hourStr = if hourFixed < 10 then "0" ++ (String.fromInt hourFixed)
          else String.fromInt hourFixed
        minutesStr = floatFractionToMinutes f
      in
        hourStr ++ ":" ++ minutesStr ++ suffix
    Hour24 ->
      let
        hour = modBy 24 (floor f)
        hourStr = if hour < 10 then "0" ++ (String.fromInt hour)
          else String.fromInt hour
        minutesStr = floatFractionToMinutes f
      in
        hourStr ++ ":" ++ minutesStr

floatToDuration : Float -> String
floatToDuration f =
  let
      hours = floor f
      hoursStr = if hours < 10 then "0" ++ (String.fromInt hours)
        else String.fromInt hours
      minutesStr = floatFractionToMinutes f
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
    Border.rounded 3,
    padding 3
  ]
    
shiftModalElement : Model -> ShiftModalData -> Element Message
shiftModalElement model shiftModalData =
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
      -- Add shift header text
      el
        [
          fillX,
          fillY,
          Font.size 30,
          BG.color white,
          padding 15
        ]
        (el 
          [
            centerX,
            centerY
          ] (text "Add a shift:")),
      -- Date display
      el
        [
          centerX,
          centerY
        ]
        (text (ymdToString shiftModalData.ymd)),
        
      -- Employee search/select
      column
        [
          spacing 15,
          paddingXY 0 15
        ]
        [
          Input.search 
            [
              defaultShadow,
              centerX,
              htmlAttribute (HtmlAttr.id "employeeSearch")
                
            ]
            {
              onChange = ShiftEmployeeSearch,
              text = shiftModalData.employeeSearch,
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
              selected = shiftModalData.employee,
              label = Input.labelHidden ("Employees"),
              options = employeeAutofillElement shiftModalData.employeeMatches
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
                    floatToTime 
                    shiftModalData.start 
                    model.settings.hourFormat
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
            value = shiftModalData.start,
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
                    shiftModalData.duration 
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
                    floatToTime
                    (shiftModalData.start +
                    shiftModalData.duration) 
                    model.settings.hourFormat
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
            value = shiftModalData.duration,
            step = Just 0.25,
            thumb = Input.defaultThumb
          }
      ],
      
      -- Save/Cancel buttons
      row 
      [
        spacing 10,
        padding 5,
        fillX
      ]
      [
        Input.button
        [
          BG.color (rgb 0.2 0.9 0.2),
          padding 5,
          defaultShadow
        ]
        {
          onPress = Just (AddShift shiftModalData),
          label = text "Save"
        },
        Input.button
        [
          BG.color (rgb 0.9 0.2 0.2),
          padding 5,
          defaultShadow,
          alignRight
        ]
        {
          onPress = Just CloseShiftModal,
          label = text "Cancel"
        }
      ]
    ]

dayOfMonthElement day =
  el 
  [
    Font.size 16
  ] 
  (
    text (String.fromInt day.day)
  )

addShiftElement day =
  Input.button
  [
    BG.color lightGreen,
    Border.rounded 5,
    Font.size 16,
    paddingEach { top = 0, bottom = 0, right = 2, left = 1}
  ]
  {
    onPress = Just (OpenShiftModal day),
    label = 
      el [moveUp 1]
        (text "+")
  }

compareDays maybe1 maybe2 =
  case (maybe1, maybe2) of
    (Just d1, Just d2) -> 
      if 
        d1.year == d2.year && 
        d1.month == d2.month && 
        d1.day == d2.day
      then Today
      else if
        d1.year < d2.year
      then Past
      else if
        d1.year <= d2.year &&
        d1.month < d2.month
      then Past
      else if
        d1.year <= d2.year &&
        d1.month <= d2.month &&
        d1.day < d2.day
      then Past
      else Future
    (_, _) -> None

type DayState =
  None |
  Past |
  Today |
  Future

dayElement : 
  Settings 
  -> List (Employee, List Shift)
  -> Maybe YearMonthDay
  -> Maybe YearMonthDay
  -> Element Message
dayElement settings employeeShifts focusDay maybeYMD =
  let dayState = (compareDays maybeYMD focusDay) in
  case maybeYMD of
    Just day -> 
      el
      (dayStyle maybeYMD dayState)
      (
        column 
        []
        [
          row
          [
            padding 5
          ]
          [
            dayOfMonthElement day,
            addShiftElement day
          ],
          shiftColumn settings day employeeShifts
        ]
      )
      
    Nothing -> 
      el 
      (dayStyle maybeYMD dayState)
      none

monthRowElement : 
  Settings 
  -> Maybe YearMonthDay
  -> List (Employee, List Shift)
  -> Row
  -> Element Message
monthRowElement settings focusDay employeeShifts rowElement =
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
        (dayElement settings employeeShifts focusDay) 
        rowElement
      )
    )

settingsElement = 
  el
    [
      alignLeft,
      BG.color (rgb 0.9 0.1 0.1),
      height fill,
      width (px 300),
      Events.onClick CloseSettingsModal
    ]
    none

viewMonthRows month focusDay settings shiftDict employees =
  column
  [
    width fill,
    height fill,
    spacing 1
  ] 
  (Array.toList 
    (Array.map 
      (monthRowElement 
      settings 
      focusDay
      (mapEmployeeShifts shiftDict employees))
    month))

fillX = width fill
fillY = height fill

viewMonth ymdMaybe month settings shiftDict employees =
  case ymdMaybe of
    Just ymd ->
      column
      [
        fillX,
        fillY
      ]
      [
        el
          [
            centerX
          ]
          (text (monthNumToString ymd.month)),
        viewMonthRows month ymdMaybe settings shiftDict employees
      ]
    Nothing -> text "Loading..."


viewModal model =
  case model.calendarModal of
    NoModal -> none
    ShiftEditorModal shiftModalData ->
      shiftModalElement model shiftModalData
    SettingsModal -> settingsElement

viewCalendar : Model -> Element Message
viewCalendar model =
  case model.settings.viewType of
    MonthView ->
      let 
        month = makeGridFromMonth 
          (case model.today of
            Just ymd -> YearMonth ymd.year ymd.month
            Nothing -> (YearMonth 2019 4))
        settings = model.settings
        shiftDict = model.employeeShifts
        employees = model.employees
      in
        column
        [
          width fill,
          height fill,
          inFront (viewModal model)
        ]
        [
          viewMonth model.today month settings shiftDict employees,
          viewCalendarFooter
        ]
    WeekView ->
      none
    DayView ->
      none

view : Model -> Browser.Document Message
view model =
  case model.page of
    LoginPage -> toDocument (viewLogin model)
    CalendarPage -> toDocument (viewCalendar model)