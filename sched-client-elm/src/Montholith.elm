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
import Element exposing (Element, Attribute)
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
    viewType : ViewType,
    hourFormat : HourFormat,
    lastNameStyle : LastNameStyle
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

type alias EmployeesData =
  {
    employees : List Employee,
    employeeShifts : Dict Int (List Shift)
  }

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
    settings : Settings,
    page : Page,
    login_info : LoginInfo,
    email_state : InputState,
    password_state : InputState,
    button_state : InputState,
    user : Maybe User,
    employeesData : EmployeesData,
    loaded : Dict Int Bool,
    hover : Maybe HoverData,
    focusDay : Maybe YearMonthDay,
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

-- DESERIALIZATION
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

stringToUserLevel levelString =
  case levelString of
    "Supervisor" -> D.succeed Supervisor
    "Admin" -> D.succeed Admin
    _ -> D.succeed Read

userLevelDecoder : D.Decoder UserLevel
userLevelDecoder =
  D.string
  |> D.andThen stringToUserLevel

userDecoder = D.succeed User
  |> JPipe.required "id" D.int
  |> JPipe.required "level" userLevelDecoder

type Arrows =
  Left |
  Up |
  Right |
  Down

arrowDecoder =
  D.map arrowMap (D.field "key" D.string)

arrowMap string =
  case string of
    "ArrowLeft" -> Just Left
    "ArrowUp" -> Just Up
    "ArrowRight" -> Just Right
    "ArrowDown" -> Just Down
    _ -> Nothing

-- SUBSCRIPTIONS
subscriptions : Model -> Sub Message
subscriptions _ =
    Sub.map KeyDown (Browser.Events.onKeyDown arrowDecoder)

-- INIT
settingsDefault = 
  Settings 
    MonthView 
    Hour12 
    FirstInitial

employeeDataDefault = EmployeesData [] Dict.empty

loadData =
  Task.perform ReceiveTime ymdNow

init : () -> Url.Url -> Nav.Key -> (Model, Cmd Message)
init _ url key =
  router 
    (
      Model 
        key
        settingsDefault
        LoginPage
        (LoginInfo "" "")
        Normal
        Normal
        Normal
        Nothing
        employeeDataDefault
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
  KeyDown (Maybe Arrows) |
  FocusResult (Result Dom.Error ()) |
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
  ChooseShiftEmployee (Employee) |
  -- SettingsModal Messages
  OpenSettingsModal |
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
  Debug.log ("Requesting shifts for employee" ++ (Debug.toString emp))
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
    "7"
    "0"
    "8"
    "0"
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
  case (Debug.log "page, message" (model.page, message)) of
    (_, UrlRequest request) ->
      case request of
        Browser.Internal url ->
          (model, Nav.pushUrl model.navkey (Url.toString url))
        _ -> (model, Cmd.none)
    (_, UrlChanged url) ->
      router model url
    (_, ReceiveTime ymd) ->
      ({ model | focusDay = Just ymd }, requestEmployees)
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
          in
            ({ loadingModel | employeesData = 
              EmployeesData 
              employees.employees 
              Dict.empty }, 
            Cmd.batch (List.map requestShifts employees.employees))
        Err e ->
          (model, Nav.pushUrl model.navkey "/sched/login")
    (_, ReceiveShifts employee shiftsResult) ->
      case shiftsResult of
        Ok shifts ->
          let
            markedModel = markTaskComplete employee.id model
          in
              
            if tasksComplete markedModel then
              ({ markedModel | employeesData = 
                EmployeesData
                  model.employeesData.employees
                  (Dict.insert 
                    employee.id
                    shifts.shifts
                    model.employeesData.employeeShifts)}, 
                  Task.succeed DoneLoading 
                  |> Task.perform identity)
            else
              ({ markedModel | employeesData = 
                EmployeesData
                  model.employeesData.employees
                  (Dict.insert 
                    employee.id
                    shifts.shifts
                    model.employeesData.employeeShifts)}, Cmd.none)
        Err e -> 
          -- (Debug.log "receive shifts error" e)
          (model, Cmd.none)
    (_, DoneLoading) -> (model, Cmd.none)
    (CalendarPage, DayClick maybeYMD) ->
      ({ model | focusDay = maybeYMD }, Cmd.none)
    (CalendarPage, OpenShiftModal day) ->
      case model.calendarModal of
        NoModal -> 
          (
            { model | calendarModal = 
              ShiftEditorModal 
                (shiftEditorForDay day model.employeesData.employees) }, 
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
                      model.employeesData.employees
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
                  (ChooseShiftEmployee 
                    (Debug.log "one employee" oneEmp)) 
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
      Element.layoutWith
      {
        options = 
        [
          -- Element.focusStyle
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
    Element.alignLeft
  ]
  {
    onPress = Just OpenSettingsModal,
    label = Element.text "Settings"
  }

viewLogoutButton =
  Input.button
  [
    Element.alignRight
  ]
  {
    onPress = Just Logout,
    label = Element.text "Log out"
  }

viewCalendarFooter : Element Message
viewCalendarFooter =
  Element.row
    [
      -- Element.explain Debug.todo,
      Element.height (Element.px 32),
      Element.width Element.fill,
      Border.solid,
      Border.color (Element.rgb 1 1 1),
      Border.width 1
    ]
    [viewSettingsToggle, viewLogoutButton]

elementShadow =
  Border.shadow
    {
      offset = (4, 4),
      size = 3,
      blur = 10,
      color = Element.rgba 0 0 0 0.5
    }

viewLogin model =
  Element.column 
    [
      Element.padding 100, 
      Element.width Element.fill,
      BG.color (Element.rgb 0.85 0.9 0.95),
      Element.centerY
    ] 
    [
      Element.column 
        [
          Element.centerX
        ]
        [
          Element.el 
            [
              Element.alignRight,
              Element.width (Element.px 300),
              Element.padding 15
            ] (Element.el [Element.centerX] (Element.text "Login to Scheduler")),
          Element.column
            [
              Element.spacing 15
            ]
            [
              Input.username
                [
                  Element.alignRight,
                  Input.focusedOnLoad,
                  Element.width (Element.px 300),
                  Element.padding 15,
                  Element.spacing 15
                ]
                {
                  label = Input.labelLeft [] (Element.text "Email"),
                  onChange = UpdateEmail,
                  placeholder = Just (Input.placeholder [] (Element.text "you@something.com")),
                  text = model.login_info.email
                },
              Input.currentPassword
                [
                  Element.alignRight,
                  Element.width (Element.px 300),
                  Element.padding 15,
                  Element.spacing 15
                ]
                {
                  onChange = UpdatePassword,
                  text = model.login_info.password,
                  label = Input.labelLeft [] (Element.text "Password"),
                  placeholder = Just (Input.placeholder [] (Element.text "Password")),
                  show = False
                }
            ],
          Element.row
            [
              Element.alignRight,
              Element.width (Element.px 300),
              Element.paddingXY 0 15
            ]
            [
              Input.button 
                [ 
                  Element.alignLeft,
                  BG.color (Element.rgb 0.25 0.8 0.25),
                  elementShadow,
                  Element.padding 10
                ]
                {
                  label = Element.text "Login",
                  onPress = Just LoginRequest
                },
              Input.button 
                [ 
                  Element.alignRight,
                  BG.color (Element.rgb 0.45 0.45 0.8),
                  elementShadow,
                  Element.padding 10
                ]
                {
                  label = Element.text "Create User",
                  onPress = Just CreateUser
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
      in (Element.text (formatHour12 start ++ "-" ++ formatHour12 end))
    Hour24 -> 
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

pairEmployeeShift : Settings -> (Employee, List Shift) -> List (Element Message)
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
  Element.row
    [
      Font.size 14,
      Element.paddingXY 0 2,
      Border.color (Element.rgb 1 0 0),
      BG.color (Element.rgba 1 0 0 0.1),
      Border.width 2,
      Border.rounded 3,
      Element.width Element.fill
    ] 
    [
      Element.text 
        (employee.name.first
        ++ " "
        ++ formatLastName settings employee.name.last
        ++ ": "),
      (formatHours settings shift.hour shift.hours)
    ]

dayStyle ymdMaybe focused = 
  [
    Element.width Element.fill,
    Element.height Element.fill,
    Border.widthEach {bottom = 0, left = 1, right = 0, top = 0},
    Border.color (Element.rgb 0.2 0.2 0.2),
    Events.onClick (DayClick ymdMaybe),
    case focused of
      True -> BG.color (Element.rgb 0.99 1 0.99)
      False -> BG.color (Element.rgb 1 1 1),
    if focused == True then
      Border.innerGlow lightGreen 3
    else Border.innerGlow (Element.rgba 0 0 0 0) 0
  ]

shiftColumn settings day employeeShifts =
  Element.column 
  [
    Element.centerX,
    Element.width Element.fill
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
    hour : String,
    minute : String,
    hours : String,
    minutes : String,
    shiftRepeat : ShiftRepeat,
    everyX : String
  }

employeeAutofillElement : List Employee -> List (Input.Option (Employee) Message)
employeeAutofillElement employeeList =
  (Debug.log "filtered list" (List.map 
    (\employee -> 
      Input.option 
      (employee)
      (
        Element.text (nameToString employee.name)
      ) 
    ) 
    employeeList))
    
modalColor = Element.rgb 0.9 0.9 0.9

lightGreen = Element.rgb 0.65 0.85 0.65
shiftModalElement : Model -> ShiftModalData -> Element Message
shiftModalElement model shiftModalData =
  Element.column
    [
      Element.centerX,
      Element.centerY,
      BG.color (Element.rgb 0.9 0.9 0.9),
      Element.padding 15,
      Border.shadow 
        {
          offset = (3, 3),
          size = 3,
          blur = 6,
          color = (Element.rgba 0 0 0 0.25)
        }
    ]
    [
      Input.search 
      [
        fillX,
        Element.htmlAttribute (HtmlAttr.id "employeeSearch")
      ]
      {
        onChange = ShiftEmployeeSearch,
        text = shiftModalData.employeeSearch,
        placeholder = Nothing,
        label = Input.labelLeft [] (Element.text "Employee: ")
      },
      Input.radio
      [
        fillX
      ]
      {
        onChange = ChooseShiftEmployee,
        selected = shiftModalData.employee,
        label = Input.labelLeft [] (Element.text "Employee: "),
        options = employeeAutofillElement shiftModalData.employeeMatches
      },
      Input.text
      []
      {
        onChange = ShiftModalUpdateDay,
        text = shiftModalData.day,
        placeholder = Just (Input.placeholder [] (Element.text "Day")),
        label = Input.labelLeft [] (Element.text "Day: ")
      },
      Element.row 
      [
        Element.spacing 10,
        Element.padding 5
      ]
      [
        Input.button
        [
          BG.color (Element.rgb 0.2 0.9 0.2),
          Element.padding 5
        ]
        {
          onPress = Just (AddShift shiftModalData),
          label = Element.text "Save"
        },
        Input.button
        [
          BG.color (Element.rgb 0.9 0.2 0.2),
          Element.padding 5
        ]
        {
          onPress = Just CloseShiftModal,
          label = Element.text "Cancel"
        }
      ]
    ]

dayOfMonthElement day =
  Element.el 
  [
    Font.size 16
  ] 
  (
    Element.text (String.fromInt day.day)
  )

addShiftElement day =
  Input.button
  [
    BG.color (Element.rgb 0.8 0.8 0.8),
    Border.rounded 5,
    Font.size 16
  ]
  {
    onPress = Just (OpenShiftModal day),
    label = Element.text "+"
  }

compareDays maybe1 maybe2 =
  case (maybe1, maybe2) of
    (Just d1, Just d2) -> 
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day
    (_, _) -> False

dayElement : 
  Settings 
  -> List (Employee, List Shift)
  -> Maybe YearMonthDay
  -> Maybe YearMonthDay
  -> Element Message
dayElement settings employeeShifts focusDay maybeYMD =
  let focused = (compareDays maybeYMD focusDay) in
  case maybeYMD of
    Just day -> 
      Element.el
      (dayStyle maybeYMD focused)
      (
        Element.column 
        []
        [
          Element.row
          [
            Element.padding 5
          ]
          [
            dayOfMonthElement day,
            addShiftElement day
          ],
          shiftColumn settings day employeeShifts
        ]
      )
      
    Nothing -> 
      Element.el 
      (dayStyle maybeYMD focused)
      Element.none

monthRowElement : 
  Settings 
  -> Maybe YearMonthDay
  -> List (Employee, List Shift)
  -> Row
  -> Element Message
monthRowElement settings focusDay employeeShifts row =
  Element.row 
    [
      Element.height Element.fill,
      Element.width Element.fill,
      Element.spacing 0,
      Border.widthEach {top = 0, bottom = 1, right = 0, left = 0}
    ] 
    (
      Array.toList 
      (
        Array.map 
        (dayElement settings employeeShifts focusDay) 
        row
      )
    )

settingsToggleElement =
  Element.el 
    [
      Element.alignLeft,
      Element.alignBottom,
      Element.padding 20,
      Events.onClick OpenSettingsModal,
      Element.width (Element.px 32),
      Element.height (Element.px 32)
    ]
    (
      Element.image 
        [
        ]
        {
          src = "/sched/gear.png",
          description = "Toggle settings panel"
        }
    )

settingsElement = 
  Element.el
    [
      Element.alignLeft,
      BG.color (Element.rgb 0.9 0.1 0.1),
      Element.height Element.fill,
      Element.width (Element.px 300),
      Events.onClick CloseSettingsModal
    ]
    Element.none

viewMonthRows month focusDay settings shiftDict employees =
  Element.column
  [
    -- Element.explain Debug.todo,
    Element.width Element.fill,
    Element.height Element.fill,
    Element.spacing 1
  ] 
  (Array.toList 
    (Array.map 
      (monthRowElement 
      settings 
      focusDay
      (mapEmployeeShifts shiftDict employees))
    month))

fillX = Element.width Element.fill
fillY = Element.height Element.fill

viewMonth ymdMaybe month settings shiftDict employees =
  case ymdMaybe of
    Just ymd ->
      Element.column
      [
        fillX,
        fillY
      ]
      [
        Element.el
          [
            Element.centerX
          ]
          (Element.text (monthNumToString ymd.month)),
        viewMonthRows month ymdMaybe settings shiftDict employees
      ]
    Nothing -> Element.text "Loading..."


viewModal model =
  case model.calendarModal of
    NoModal -> Element.none
    ShiftEditorModal shiftModalData ->
      shiftModalElement model shiftModalData
    SettingsModal -> settingsElement

viewCalendar : Model -> Element Message
viewCalendar model =
  case model.settings.viewType of
    MonthView ->
      let 
        month = makeGridFromMonth 
          (case model.focusDay of
            Just ymd -> YearMonth ymd.year ymd.month
            Nothing -> (YearMonth 2019 4))
        settings = model.settings
        shiftDict = model.employeesData.employeeShifts
        employees = model.employeesData.employees
      in
        Element.column
        [
          -- Element.explain Debug.todo,
          Element.width Element.fill,
          Element.height Element.fill,
          Element.inFront (viewModal model)
        ]
        [
          viewMonth model.focusDay month settings shiftDict employees,
          viewCalendarFooter
        ]
    WeekView ->
      Element.none
    DayView ->
      Element.none

view : Model -> Browser.Document Message
view model =
  case model.page of
    LoginPage -> toDocument (viewLogin model)
    CalendarPage -> toDocument (viewCalendar model)