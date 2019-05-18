module Main exposing (CalendarData, CalendarModal(..), ColorPair, ColorRecord, CombinedSettings, DayID, DayState(..), Employee, EmployeeColor(..), EmployeeLevel(..), HourFormat(..), HoverData, InputState(..), Keys(..), LastNameStyle(..), LoginInfo, LoginModel, Message(..), Model, Month, Name, Page(..), PerEmployeeSettings, RowID, Settings, Shift, ShiftRepeat(..), ViewEditData, ViewSelectData, ViewType(..), Week, Weekdays(..), YearMonth, YearMonthDay, addEventButton, allEmpty, basicButton, black, borderColor, borderL, borderR, centuryCode, chooseSuffix, colorDisplay, colorSelectOpenButton, colorSelector, combinedSettingsDecoder, dayCompare, dayOfMonthElement, dayRepeatMatch, dayStyle, daysApart, daysInMonth, daysLeftInMonth, defaultBorder, defaultCalendarModel, defaultID, defaultLoginModel, defaultShadow, defaultViewEdit, editViewButton, editViewElement, employeeAutofillElement, employeeColor, employeeColorDecoder, employeeColorEncoder, employeeDecoder, employeeDefault, employeeEncoder, employeeLevelDecoder, employeeLevelEncoder, employeeRGB, employeeToCheckbox, employeeToColorPicker, encodeLoginInfo, endsFromStartDur, fillX, fillY, filterShiftsByDate, floatToDurationString, floatToHour, floatToMinuteString, floatToQuarterHour, floatToTimeString, foldAddDaysBetween, foldAllEmpty, foldDaysLeftInYear, foldPlaceDay, foldRowSelect, formatHour12, formatHour24, formatHours, formatLastName, fromZellerWeekday, genericObjectDecoder, getActiveSettings, getDayState, getEmployee, getEmployeeSettings, getPosixTime, getSettings, getTime, getTimeZone, getViewEmployees, green, grey, headerFontSize, hourFormatDecoder, hourFormatEncoder, hourMinuteToFloat, init, isLeapYear, keyDecoder, keyMap, lastNameStyleDecoder, lastNameStyleEncoder, leapYearOffset, lightGreen, lightGrey, loadData, loginRequest, main, makeDaysForMonth, makeGridFromMonth, makeWeekFromYMD, modalColor, monthCode, monthDefault, monthNumToString, monthToNum, nameDecoder, nameEncoder, nameToString, perEmployeeSettingsDecoder, perEmployeeSettingsEncoder, placeDays, postShiftSpace, preShiftSpace, red, requestDefaultSettings, requestEmployees, requestSettings, requestShifts, rowDefault, searchRadio, selectPositionForDay, selectViewButton, selectViewElement, settingsDecoder, settingsDefault, settingsEncoder, settingsToOption, shiftColumn, shiftCompare, shiftDate, shiftDecoder, shiftEditElement, shiftElement, shiftEncoder, shiftHourCompare, shiftMatch, shiftQuarterHours, shiftRepeatDecoder, shiftRepeatEncoder, shiftSpace, subscriptions, toDocument, toWeekday, update, updateLoginButton, updateSettings, updateShift, view, viewCalendar, viewCalendarFooter, viewDayInMonth, viewLogin, viewLogoutButton, viewModal, viewMonth, viewMonthRows, viewTypeDecoder, viewTypeEncoder, viewYMDDecoder, weekDaysView, weekRepeatMatch, weekdayNumToString, white, withDay, yearLastTwo, yellow, ymFromYmd, ymdNextMonth, ymdPriorMonth, ymdToString)

import Array exposing (Array)
import Browser
import Browser.Dom as Dom
import Browser.Events
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Element exposing (..)
import Element.Background as BG
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Html.Attributes as HtmlAttr
import Http
import Json.Decode as D
import Json.Decode.Pipeline as JPipe
import Json.Encode as E
import List.Extra
import Simple.Fuzzy as Fuzzy
import Task
import Time
import Url
import Url.Builder as UB



-- MAIN


main : Program () Model Message
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = UrlRequest
        }



-- MODEL


type ViewType
    = MonthView
    | WeekView
    | DayView
    | AltDayView


type HourFormat
    = Hour12
    | Hour24


type LastNameStyle
    = FullName
    | FirstInitial
    | Hidden


type alias Settings =
    { id : Int
    , employeeID : Int
    , name : String
    , viewType : ViewType
    , hourFormat : HourFormat
    , lastNameStyle : LastNameStyle
    , viewDate : YearMonthDay
    , viewEmployees : List Int
    , showMinutes : Bool
    , showShifts : Bool
    , showVacations : Bool
    , showCallShifts : Bool
    }


type EmployeeColor
    = Red
    | LightRed
    | Green
    | LightGreen
    | Blue
    | LightBlue
    | Yellow
    | LightYellow
    | Grey
    | LightGrey
    | Black
    | Brown
    | Purple


type alias ColorRecord =
    { red : Float
    , green : Float
    , blue : Float
    , alpha : Float
    }


type alias ColorPair =
    { light : ColorRecord
    , dark : ColorRecord
    }


employeeRGB : EmployeeColor -> ColorRecord
employeeRGB c =
    case c of
        Red ->
            { red = 1, green = 0.5, blue = 0.5, alpha = 0 }

        LightRed ->
            { red = 1, green = 0.827, blue = 0.941, alpha = 0 }

        Green ->
            { red = 0.5, green = 1, blue = 0.5, alpha = 0 }

        LightGreen ->
            { red = 0.75, green = 1, blue = 0.729, alpha = 0 }

        Blue ->
            { red = 0.5, green = 0.5, blue = 1, alpha = 0 }

        LightBlue ->
            { red = 0.655, green = 0.918, blue = 0.976, alpha = 0 }

        Yellow ->
            { red = 1, green = 1, blue = 0.5, alpha = 0 }

        LightYellow ->
            { red = 1, green = 1, blue = 0.75, alpha = 0 }

        Grey ->
            { red = 0.75, green = 0.75, blue = 0.75, alpha = 0 }

        LightGrey ->
            { red = 0.95, green = 0.95, blue = 0.95, alpha = 0 }

        Black ->
            { red = 0.25, green = 0.25, blue = 0.25, alpha = 0 }

        Brown ->
            { red = 0.65, green = 0.35, blue = 0.2, alpha = 0 }

        Purple ->
            { red = 0.8, green = 0.729, blue = 1, alpha = 0 }


employeeColor : EmployeeColor -> ColorPair
employeeColor c =
    let
        crgb =
            employeeRGB c
    in
    ColorPair
        { crgb | alpha = 1 }
        { crgb | alpha = 1 }


type alias PerEmployeeSettings =
    { id : Int
    , settingsID : Int
    , employeeID : Int
    , color : EmployeeColor
    }


type alias CombinedSettings =
    { settings : Settings
    , perEmployee : List PerEmployeeSettings
    }


ymdPriorMonth : YearMonthDay -> YearMonthDay
ymdPriorMonth ymd =
    case ymd.month of
        1 ->
            { ymd | year = ymd.year - 1, month = 12 }

        _ ->
            { ymd | month = ymd.month - 1 }


ymdNextMonth : YearMonthDay -> YearMonthDay
ymdNextMonth ymd =
    case ymd.month of
        12 ->
            { ymd | year = ymd.year + 1, month = 1 }

        _ ->
            { ymd | month = ymd.month + 1 }


type InputState
    = Normal
    | Success
    | Danger
    | Disabled


type alias LoginInfo =
    { email : String
    , password : String
    }


type EmployeeLevel
    = Read
    | Supervisor
    | Admin


type alias Name =
    { first : String
    , last : String
    }


type alias Employee =
    { id : Int
    , email : String
    , startupSettings : Maybe Int
    , level : EmployeeLevel
    , name : Name
    , phoneNumber : Maybe String
    , defaultColor : EmployeeColor
    }


employeeDefault =
    Employee
        0
        ""
        Nothing
        Read
        (Name "" "")
        Nothing


type alias HoverData =
    {}


type alias LoginModel =
    { loginInfo : LoginInfo
    , emailState : InputState
    , passwordState : InputState
    , buttonState : InputState
    }


defaultLoginModel =
    LoginModel
        (LoginInfo "" "")
        Normal
        Normal
        Normal


type alias EmployeeEditData =
    { employeeSearchText : String
    , filteredEmployees : List Employee
    , employee : Maybe Employee
    , password : String
    }


type alias AccountModalData =
    { colorSelectOpen : Bool
    , phoneNumber : String
    , oldPassword : String
    , newPassword : String
    , newPasswordAgain : String
    , status : String
    }


type CalendarModal
    = NoModal
    | ViewSelectModal
    | ViewEditModal ViewEditData
    | AddEventModal YearMonthDay
    | ShiftModal ShiftData
    | VacationModal VacationData
    | EmployeeEditor EmployeeEditData
    | VacationApprovalModal
    | AccountModal AccountModalData


type alias CalendarData =
    { modal : CalendarModal
    }


defaultCalendarModel =
    CalendarData
        NoModal


type Page
    = LoginPage LoginModel
    | CalendarPage CalendarData


type alias Model =
    { navkey : Nav.Key
    , -- loaded data
      settingsList : Maybe (List CombinedSettings)
    , activeSettings : Maybe Int
    , currentEmployee : Maybe Employee
    , employees : Maybe (List Employee)
    , shifts : Maybe (List Shift)
    , vacations : Maybe (List Vacation)
    , posixNow : Maybe Time.Posix
    , here : Maybe Time.Zone
    , updateViewDate : Bool
    , -- per page data
      page : Page
    }


type alias VacationApproveData =
    { selected : Maybe Vacation }


type alias Vacation =
    { id : Int
    , supervisorID : Maybe Int
    , employeeID : Int
    , approved : Bool
    , startYear : Int
    , startMonth : Int
    , startDay : Int
    , durationDays : Maybe Int
    , requestYear : Int
    , requestMonth : Int
    , requestDay : Int
    }


type alias Shift =
    { id : Int
    , supervisorID : Int
    , employeeID : Maybe Int
    , year : Int
    , month : Int
    , day : Int
    , hour : Int
    , minute : Int
    , hours : Int
    , minutes : Int
    , repeat : ShiftRepeat
    , everyX : Maybe Int
    , note : Maybe String
    , onCall : Bool
    }


type Event
    = VacationEvent Vacation
    | ShiftEvent Shift


type alias YearMonthDay =
    { year : Int
    , month : Int
    , day : Int
    }


type alias YearMonth =
    { year : Int
    , month : Int
    }


type Weekdays
    = Sun
    | Mon
    | Tue
    | Wed
    | Thu
    | Fri
    | Sat
    | Invalid


monthToNum month =
    case month of
        Time.Jan ->
            1

        Time.Feb ->
            2

        Time.Mar ->
            3

        Time.Apr ->
            4

        Time.May ->
            5

        Time.Jun ->
            6

        Time.Jul ->
            7

        Time.Aug ->
            8

        Time.Sep ->
            9

        Time.Oct ->
            10

        Time.Nov ->
            11

        Time.Dec ->
            12


monthNumToString num =
    case num of
        1 ->
            "January"

        2 ->
            "February"

        3 ->
            "March"

        4 ->
            "April"

        5 ->
            "May"

        6 ->
            "June"

        7 ->
            "July"

        8 ->
            "August"

        9 ->
            "September"

        10 ->
            "October"

        11 ->
            "November"

        12 ->
            "December"

        _ ->
            "Unknown"


weekdayNumToString num =
    case num of
        1 ->
            "Sunday"

        2 ->
            "Monday"

        3 ->
            "Tuesday"

        4 ->
            "Wednesday"

        5 ->
            "Thursday"

        6 ->
            "Friday"

        7 ->
            "Saturday"

        _ ->
            "Unknown"



-- SERIALIZATION


encodeLoginInfo : LoginInfo -> E.Value
encodeLoginInfo loginValue =
    E.object
        [ ( "email", E.string loginValue.email )
        , ( "password", E.string loginValue.password )
        ]


nameEncoder : Name -> E.Value
nameEncoder n =
    E.object
        [ ( "first", E.string n.first )
        , ( "last", E.string n.last )
        ]


employeeEncoder : Employee -> E.Value
employeeEncoder e =
    E.object
        [ ( "id", E.int e.id )
        , ( "email", E.string e.email )
        , ( "startup_settings"
          , case e.startupSettings of
                Just ss ->
                    E.int ss

                Nothing ->
                    E.null
          )
        , ( "level", employeeLevelEncoder e.level )
        , ( "name", nameEncoder e.name )
        , case e.phoneNumber of
            Just pn ->
                ( "phone_number", E.string pn )

            Nothing ->
                ( "phone_number", E.null )
        , ("default_color", employeeColorEncoder e.defaultColor )
        ]

loginInfoEncoder : AccountModalData -> E.Value
loginInfoEncoder modalData =
    E.object
    [ ( "old_password", E.string modalData.oldPassword )
    , ( "new_password", E.string modalData.newPassword )
    ]


employeeLevelEncoder : EmployeeLevel -> E.Value
employeeLevelEncoder level =
    case level of
        Supervisor ->
            E.string "Supervisor"

        Admin ->
            E.string "Admin"

        _ ->
            E.string "Read"


viewTypeEncoder : ViewType -> E.Value
viewTypeEncoder viewType =
    case viewType of
        MonthView ->
            E.string "Month"

        WeekView ->
            E.string "Week"

        DayView ->
            E.string "Day"
        
        AltDayView ->
            E.string "AltDay"


hourFormatEncoder : HourFormat -> E.Value
hourFormatEncoder hourFormat =
    case hourFormat of
        Hour12 ->
            E.string "Hour12"

        Hour24 ->
            E.string "Hour24"


lastNameStyleEncoder : LastNameStyle -> E.Value
lastNameStyleEncoder lastNameStyle =
    case lastNameStyle of
        FullName ->
            E.string "FullName"

        FirstInitial ->
            E.string "FirstInitial"

        Hidden ->
            E.string "Hidden"


shiftRepeatEncoder : ShiftRepeat -> E.Value
shiftRepeatEncoder repeat =
    case repeat of
        NeverRepeat ->
            E.string "NeverRepeat"

        EveryWeek ->
            E.string "EveryWeek"

        EveryDay ->
            E.string "EveryDay"


settingsEncoder : Settings -> E.Value
settingsEncoder settings =
    E.object
        [ ( "id", E.int settings.id )
        , ( "employee_id", E.int settings.employeeID )
        , ( "name", E.string settings.name )
        , ( "view_type", viewTypeEncoder settings.viewType )
        , ( "hour_format", hourFormatEncoder settings.hourFormat )
        , ( "last_name_style", lastNameStyleEncoder settings.lastNameStyle )
        , ( "view_year", E.int settings.viewDate.year )
        , ( "view_month", E.int settings.viewDate.month )
        , ( "view_day", E.int settings.viewDate.day )
        , ( "view_employees", E.list E.int settings.viewEmployees )
        , ( "show_minutes", E.bool settings.showMinutes )
        , ( "show_shifts", E.bool settings.showShifts )
        , ( "show_vacations", E.bool settings.showVacations )
        , ( "show_call_shifts", E.bool settings.showCallShifts )
        ]

stringToColor : String -> EmployeeColor
stringToColor color =
    case color of
        "Red" ->
            Red

        "LightRed" ->
            LightRed

        "Green" ->
            Green

        "LightGreen" ->
            LightGreen

        "LightBlue" ->
            LightBlue

        "Yellow" ->
            Yellow

        "LightYellow" ->
            LightYellow

        "Grey" ->
            Grey

        "LightGrey" ->
            LightGrey

        "Black" ->
            Black

        "Brown" ->
            Brown

        "Purple" ->
            Purple

        _ ->
            Blue
            

colorToString : EmployeeColor -> String
colorToString c =
    case c of
        Red ->
            "Red"

        LightRed ->
            "LightRed"

        Green ->
            "Green"

        LightGreen ->
            "LightGreen"

        Blue ->
            "Blue"

        LightBlue ->
            "LightBlue"

        Yellow ->
            "Yellow"

        LightYellow ->
            "LightYellow"

        Grey ->
            "Grey"

        LightGrey ->
            "LightGrey"

        Black ->
            "Black"

        Brown ->
            "Brown"

        Purple ->
            "Purple"


employeeColorEncoder : EmployeeColor -> E.Value
employeeColorEncoder c =
    E.string <| colorToString c

httpErrorString : Http.Error -> String
httpErrorString e =
    case e of
        Http.BadUrl u -> "Bad URL: " ++ u ++ "!"
        Http.Timeout -> "Request timeout!"
        Http.NetworkError -> "Network Error!"
        Http.BadStatus i -> "Bad request status: " ++ (String.fromInt i)
        Http.BadBody b -> "Error: " ++ b

perEmployeeSettingsEncoder : PerEmployeeSettings -> E.Value
perEmployeeSettingsEncoder perEmployee =
    E.object
        [ ( "id", E.int perEmployee.id )
        , ( "settings_id", E.int perEmployee.settingsID )
        , ( "employee_id", E.int perEmployee.employeeID )
        , ( "color", employeeColorEncoder perEmployee.color )
        ]


combinedSettingsEncoder : CombinedSettings -> E.Value
combinedSettingsEncoder combined =
    E.object
        [ ( "settings", settingsEncoder combined.settings )
        , ( "per_employee", E.list perEmployeeSettingsEncoder combined.perEmployee )
        ]


shiftEncoder : Shift -> E.Value
shiftEncoder shift =
    E.object
        [ ( "id", E.int shift.id )
        , ( "supervisor_id", E.int shift.supervisorID )
        , ( "employee_id"
          , case shift.employeeID of
                Just eid ->
                    E.int eid

                Nothing ->
                    E.null
          )
        , ( "year", E.int shift.year )
        , ( "month", E.int shift.month )
        , ( "day", E.int shift.day )
        , ( "hour", E.int shift.hour )
        , ( "minute", E.int shift.minute )
        , ( "hours", E.int shift.hours )
        , ( "minutes", E.int shift.minutes )
        , ( "shift_repeat", shiftRepeatEncoder shift.repeat )
        , ( "every_x"
          , case shift.everyX of
                Just everyX ->
                    E.int everyX

                Nothing ->
                    E.null
          )
        , ( "note"
          , case shift.note of
                Just note ->
                    E.string note

                Nothing ->
                    E.null
          )
        , ( "on_call", E.bool shift.onCall )
        ]


vacationEncoder : Vacation -> E.Value
vacationEncoder vacation =
    E.object
        [ ( "id", E.int vacation.id )
        , ( "supervisor_id"
          , case vacation.supervisorID of
                Just supervisorID ->
                    E.int supervisorID

                Nothing ->
                    E.null
          )
        , ( "employee_id", E.int vacation.employeeID )
        , ( "approved", E.bool vacation.approved )
        , ( "start_year", E.int vacation.startYear )
        , ( "start_month", E.int vacation.startMonth )
        , ( "start_day", E.int vacation.startDay )
        , ( "duration_days"
          , case vacation.durationDays of
                Just durationDays ->
                    E.int durationDays

                Nothing ->
                    E.null
          )
        , ( "request_year", E.int vacation.requestYear )
        , ( "request_month", E.int vacation.requestMonth )
        , ( "request_day", E.int vacation.requestDay )
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
        |> JPipe.required "employee_id" D.int
        |> JPipe.required "name" D.string
        |> JPipe.required "view_type" viewTypeDecoder
        |> JPipe.required "hour_format" hourFormatDecoder
        |> JPipe.required "last_name_style" lastNameStyleDecoder
        |> JPipe.custom viewYMDDecoder
        |> JPipe.required "view_employees" (D.list D.int)
        |> JPipe.required "show_minutes" D.bool
        |> JPipe.required "show_shifts" D.bool
        |> JPipe.required "show_vacations" D.bool
        |> JPipe.required "show_call_shifts" D.bool


employeeColorDecoder : D.Decoder EmployeeColor
employeeColorDecoder =
    D.string
        |> D.andThen
            (\s -> D.succeed <| stringToColor s)


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
            (\viewTypeString ->
                case viewTypeString of
                    "Week" ->
                        D.succeed WeekView

                    "Day" ->
                        D.succeed DayView

                    "AltDay" ->
                        D.succeed AltDayView

                    _ ->
                        D.succeed MonthView
            )


hourFormatDecoder : D.Decoder HourFormat
hourFormatDecoder =
    D.string
        |> D.andThen
            (\hourFormatString ->
                case hourFormatString of
                    "Hour24" ->
                        D.succeed Hour24

                    _ ->
                        D.succeed Hour12
            )


lastNameStyleDecoder : D.Decoder LastNameStyle
lastNameStyleDecoder =
    D.string
        |> D.andThen
            (\styleString ->
                case styleString of
                    "FirstInitial" ->
                        D.succeed FirstInitial

                    "Hidden" ->
                        D.succeed Hidden

                    _ ->
                        D.succeed FullName
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
        |> JPipe.required "email" D.string
        |> JPipe.required "startup_settings" (D.maybe D.int)
        |> JPipe.required "level" employeeLevelDecoder
        |> JPipe.required "name" nameDecoder
        |> JPipe.required "phone_number" (D.maybe D.string)
        |> JPipe.required "default_color" employeeColorDecoder


shiftRepeatDecoder : D.Decoder ShiftRepeat
shiftRepeatDecoder =
    D.string
        |> D.andThen
            (\string ->
                case string of
                    "EveryWeek" ->
                        D.succeed EveryWeek

                    "EveryDay" ->
                        D.succeed EveryDay

                    _ ->
                        D.succeed NeverRepeat
            )


shiftDecoder : D.Decoder Shift
shiftDecoder =
    D.succeed Shift
        |> JPipe.required "id" D.int
        |> JPipe.required "supervisor_id" D.int
        |> JPipe.required "employee_id" (D.maybe D.int)
        |> JPipe.required "year" D.int
        |> JPipe.required "month" D.int
        |> JPipe.required "day" D.int
        |> JPipe.required "hour" D.int
        |> JPipe.required "minute" D.int
        |> JPipe.required "hours" D.int
        |> JPipe.required "minutes" D.int
        |> JPipe.required "shift_repeat" shiftRepeatDecoder
        |> JPipe.required "every_x" (D.maybe D.int)
        |> JPipe.required "note" (D.maybe D.string)
        |> JPipe.required "on_call" D.bool


vacationDecoder : D.Decoder Vacation
vacationDecoder =
    D.succeed Vacation
        |> JPipe.required "id" D.int
        |> JPipe.required "supervisor_id" (D.maybe D.int)
        |> JPipe.required "employee_id" D.int
        |> JPipe.required "approved" D.bool
        |> JPipe.required "start_year" D.int
        |> JPipe.required "start_month" D.int
        |> JPipe.required "start_day" D.int
        |> JPipe.required "duration_days" (D.maybe D.int)
        |> JPipe.required "request_year" D.int
        |> JPipe.required "request_month" D.int
        |> JPipe.required "request_day" D.int


employeeLevelDecoder : D.Decoder EmployeeLevel
employeeLevelDecoder =
    D.string
        |> D.andThen
            (\levelString ->
                case levelString of
                    "Supervisor" ->
                        D.succeed Supervisor

                    "Admin" ->
                        D.succeed Admin

                    _ ->
                        D.succeed Read
            )


type Keys
    = Left
    | Up
    | Right
    | Down
    | Enter
    | Escape


keyDecoder =
    D.map keyMap (D.field "key" D.string)


keyMap string =
    case string of
        "ArrowLeft" ->
            Just Left

        "ArrowUp" ->
            Just Up

        "ArrowRight" ->
            Just Right

        "ArrowDown" ->
            Just Down

        "Enter" ->
            Just Enter

        "Escape" ->
            Just Escape

        _ ->
            Nothing



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

checkToken : Message -> Message -> Cmd Message
checkToken onFail onSuccess =
    Http.post
        { url = "/sched/check_token"
        , body = Http.emptyBody
        , expect = Http.expectWhatever (CheckTokenResponse onFail onSuccess)
        }

init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Message )
init _ _ key =
        let 
            model = Model
                key
                Nothing
                Nothing
                Nothing
                Nothing
                Nothing
                Nothing
                Nothing
                Nothing
                True
                (LoginPage defaultLoginModel)

            req = checkToken GoToLogin GoToCalendar
        in ( model, req )


-- UPDATE


type
    Message
    -- General Messages
    = NoOp
    | IgnoreReply (Result Http.Error ())
    | CheckTokenResponse Message Message (Result Http.Error ())
    | GoToLogin
    | GoToCalendar
    | UrlChanged Url.Url
    | UrlRequest Browser.UrlRequest
    | Logout
    | LogoutResponse (Result Http.Error ())
    | KeyDown (Maybe Keys)
    | FocusResult (Result Dom.Error ())
      -- Account modal messages
    | OpenAccountModal
    | OpenDefaultColorSelector
    | UpdateAccountDefaultColor EmployeeColor
    | UpdateAccountPhoneNumber String
    | AccountModalUnfocusPhoneNumber
    | UpdateAccountOldPassword String
    | UpdateAccountNewPassword String
    | UpdateAccountNewPasswordAgain String
    | ChangePassword 
    | ChangePasswordResponse (Result Http.Error ())
    | CloseAccountModal
      -- Login Messages
    | LoginRequest
    | LoginResponse (Result Http.Error ())
    | UpdateEmail String
    | UpdatePassword String
      -- Calendar Messages
    | OverShift ( Employee, Shift )
    | LeaveShift
    | DayClick (Maybe YearMonthDay)
    | PriorMonth
    | NextMonth
    | PriorWeek
    | NextWeek
    | PriorDay
    | NextDay
      -- Employee Editor Messages
    | OpenEmployeeEditor
    | CloseEmployeeEditor
    | EmployeeEditNewEmployee
    | EmployeeEditGetNewEmployee (Result Http.Error Employee)
    | UpdateEmployeeEditorSearch String
    | EmployeeEditorChooseEmployee Employee
    | EmployeeEditUpdateEmail String
    | EmployeeEditUpdateFirstName String
    | EmployeeEditUpdateLastName String
    | EmployeeEditUpdatePhoneNumber String
    | EmployeeEditRemoveEmployee
      -- Event Modal Messages
    | OpenAddEvent YearMonthDay
    | CancelAddEvent
    | OpenShiftModal ShiftData
    | OpenVacationModal VacationData
    | CloseEventModal
    | CreateShiftRequest YearMonthDay
    | CreateShiftResponse (Result Http.Error Shift)
    | CreateCallShiftRequest YearMonthDay
    | CreateCallShiftResponse (Result Http.Error Shift)
    | RemoveEventAndClose Event
    | EventToggleEdit
    | UpdateVacationSupervisor Employee
    | UpdateVacationDuration String
    | CreateVacationRequest YearMonthDay
    | CreateVacationResponse (Result Http.Error Vacation)
    | ShiftEmployeeSearch String
    | ShiftEditUpdateNote String
    | ShiftEditUnfocusNote
    | ChooseShiftEmployee Employee
    | UpdateShiftStart Float
    | UpdateShiftDuration Float
    | UpdateShiftRepeat ShiftRepeat
    | UpdateShiftRepeatRate String
    | UpdateShiftOnCall Bool
      -- View Select Messages
    | OpenViewSelect
    | ChooseActiveView Int
    | RemoveView
    | DuplicateView
    | CloseViewSelect
      -- View Edit Messages
    | OpenViewEdit
    | UpdateViewName String
    | ViewEditUnfocusName
    | UpdateViewType ViewType
    | UpdateHourFormat HourFormat
    | UpdateLastNameStyle LastNameStyle
    | UpdateShowMinutes Bool
    | UpdateShowShifts Bool
    | UpdateShowCallShifts Bool
    | UpdateShowVacations Bool
    | EmployeeViewCheckbox Int Bool
    | OpenEmployeeColorSelector Employee
    | ChooseEmployeeColor Employee EmployeeColor
    | SaveView
    | CloseViewEdit
    | NewVacationRequest
      -- Vacation Approval Messages
    | OpenVacationApprovalModal
    | UpdateVacationApproval Vacation Bool
    | CloseVacationApprovalModal
      -- Loading Messages
    | ReceiveCurrentEmployee (Result Http.Error Employee)
    | ReceiveEmployees (Result Http.Error (List Employee))
    | ReceiveShifts (Result Http.Error (List Shift))
    | ReceiveVacations (Result Http.Error (List Vacation))
    | ReceiveDefaultSettings (Result Http.Error (Maybe Int))
    | ReceiveSettingsList (Result Http.Error (List CombinedSettings))
    | ReceivePosixTime Time.Posix
    | ReceiveZone Time.Zone
    | ReloadData (Result Http.Error ())


matchPasswords : AccountModalData -> Maybe String
matchPasswords modalData =
    case modalData.newPassword == modalData.newPasswordAgain of
        True -> Just modalData.newPassword
        False -> Nothing

updateViewDate : Model -> ( Model, Cmd Message )
updateViewDate model =
    case ( model.posixNow, model.here, model.updateViewDate ) of
        ( Just posixTime, Just here, True ) ->
            case ( model.settingsList, getActiveSettings model ) of
                ( Just settingsList, Just active ) ->
                    let
                        today =
                            getTime posixTime here

                        settings =
                            active.settings

                        updatedSettings =
                            { settings | viewDate = today }

                        updatedCombined =
                            { active | settings = updatedSettings }

                        updatedSettingsList =
                            updateSettingsList settingsList updatedCombined

                        updatedModel =
                            { model | settingsList = Just updatedSettingsList, updateViewDate = False }
                    in
                    ( updatedModel
                    , Http.post
                        { url = "/sched/update_settings"
                        , body = Http.jsonBody <| settingsEncoder updatedSettings
                        , expect = Http.expectWhatever IgnoreReply
                        }
                    )

                _ ->
                    ( model, Cmd.none )

        _ ->
            ( model, Cmd.none )


updateEmployee : Employee -> Cmd Message
updateEmployee employee =
    Http.post
        { url = "/sched/update_employee"
        , body = Http.jsonBody <| employeeEncoder employee
        , expect = Http.expectWhatever ReloadData
        }


getEmployeeSettings : Model -> Maybe Int -> Maybe PerEmployeeSettings
getEmployeeSettings model maybeID =
    case ( getActiveSettings model, maybeID ) of
        ( Just active, Just id ) ->
            List.filter
                (\p_e -> p_e.employeeID == id)
                active.perEmployee
                |> List.head

        _ ->
            Nothing


loginRequest : LoginInfo -> Cmd Message
loginRequest loginInfo =
    Http.post
        { url = UB.absolute [ "sched", "login_request" ] []
        , body = Http.jsonBody (encodeLoginInfo loginInfo)
        , expect = Http.expectWhatever LoginResponse
        }


updateLoginButton : LoginModel -> LoginModel
updateLoginButton page =
    if
        page.emailState
            == Success
            && page.passwordState
            == Success
    then
        { page | buttonState = Success }

    else
        { page | buttonState = Normal }


nameToString : Name -> LastNameStyle -> String
nameToString name lastNameStyle =
    name.first
        ++ (if lastNameStyle == Hidden then
                ""

            else
                " "
           )
        ++ formatLastName lastNameStyle name.last


requestEmployees : Cmd Message
requestEmployees =
    Http.post
        { url = "/sched/get_employees"
        , body = Http.emptyBody
        , expect = Http.expectJson ReceiveEmployees (genericObjectDecoder (D.list employeeDecoder))
        }


requestCurrentEmployee : Cmd Message
requestCurrentEmployee =
    Http.post
        { url = "/sched/get_current_employee"
        , body = Http.emptyBody
        , expect = Http.expectJson ReceiveCurrentEmployee employeeDecoder
        }


requestShifts : Cmd Message
requestShifts =
    Http.post
        { url = "/sched/get_shifts"
        , body = Http.emptyBody
        , expect = Http.expectJson ReceiveShifts (genericObjectDecoder (D.list shiftDecoder))
        }


requestVacations : Cmd Message
requestVacations =
    Http.post
        { url = "/sched/get_vacations"
        , body = Http.emptyBody
        , expect = Http.expectJson ReceiveVacations (genericObjectDecoder (D.list vacationDecoder))
        }


monthCode : Dict Int Int
monthCode =
    Dict.fromList
        [ ( 1, 1 )
        , ( 2, 4 )
        , ( 3, 4 )
        , ( 4, 0 )
        , ( 5, 2 )
        , ( 6, 5 )
        , ( 7, 0 )
        , ( 8, 3 )
        , ( 9, 6 )
        , ( 10, 1 )
        , ( 11, 4 )
        , ( 12, 6 )
        ]


centuryCode : Int -> Int
centuryCode year =
    let
        modyear =
            modBy 400 year
    in
    if modyear >= 0 && modyear < 100 then
        6

    else if modyear >= 100 && modyear < 200 then
        4

    else if modyear >= 200 && modyear < 300 then
        2

    else
        0



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
    if year >= 1000 then
        yearLastTwo (year - 1000)

    else if year >= 100 then
        yearLastTwo (year - 100)

    else
        year


isLeapYear : Int -> Bool
isLeapYear year =
    modBy 4 year == 0


leapYearOffset : YearMonthDay -> Int
leapYearOffset ymd =
    if isLeapYear ymd.year then
        case ymd.month of
            1 ->
                -1

            2 ->
                -1

            _ ->
                0

    else
        0


daysInMonth : YearMonth -> Int
daysInMonth ym =
    case ym.month of
        1 ->
            31

        2 ->
            case isLeapYear ym.year of
                True ->
                    29

                False ->
                    28

        3 ->
            31

        4 ->
            30

        5 ->
            31

        6 ->
            30

        7 ->
            31

        8 ->
            31

        9 ->
            30

        10 ->
            31

        11 ->
            30

        12 ->
            31

        _ ->
            30


fromZellerWeekday : Int -> Int
fromZellerWeekday zellerDay =
    modBy 7 (zellerDay - 1) + 1


toWeekday : YearMonthDay -> Int
toWeekday ymd =
    let
        lastTwo =
            yearLastTwo ymd.year

        centuryOffset =
            centuryCode ymd.year
    in
    fromZellerWeekday <|
        remainderBy 7
            (lastTwo
                // 4
                + ymd.day
                + Maybe.withDefault 0 (Dict.get ymd.month monthCode)
                + leapYearOffset ymd
                + centuryOffset
                + lastTwo
            )


hourMinuteToFloat : Int -> Int -> Float
hourMinuteToFloat hour minute =
    let
        fraction =
            toFloat (round (toFloat minute / 15)) / 4
    in
    toFloat hour + fraction


loadData =
    Cmd.batch
        [ getPosixTime
        , getTimeZone
        , requestCurrentEmployee
        , requestEmployees
        , requestShifts
        , requestVacations
        , requestSettings
        , requestDefaultSettings
        ]

requestSettings =
    Http.post
        { url = "/sched/get_settings"
        , body = Http.emptyBody
        , expect =
            Http.expectJson
                ReceiveSettingsList
            <|
                genericObjectDecoder
                    (D.list combinedSettingsDecoder)
        }


requestDefaultSettings =
    Http.post
        { url = "/sched/default_settings"
        , body = Http.emptyBody
        , expect =
            Http.expectJson
                ReceiveDefaultSettings
            <|
                genericObjectDecoder
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

        _ ->
            Nothing


getActiveSettings : Model -> Maybe CombinedSettings
getActiveSettings model =
    case ( model.activeSettings, model.settingsList ) of
        ( Just activeID, Just settingsList ) ->
            List.filter (\s -> s.settings.id == activeID) settingsList
                |> List.head

        _ ->
            Nothing


updateSettings : Settings -> Cmd Message
updateSettings settings =
    Http.post
        { url = "/sched/update_settings"
        , body =
            Http.jsonBody <|
                settingsEncoder settings
        , expect = Http.expectWhatever ReloadData
        }


removeSettingsFromList : List CombinedSettings -> CombinedSettings -> List CombinedSettings
removeSettingsFromList settingsList toRemove =
    List.Extra.filterNot (\s -> s.settings.id == toRemove.settings.id) settingsList


updateSettingsList : List CombinedSettings -> CombinedSettings -> List CombinedSettings
updateSettingsList settingsList updated =
    let
        without =
            removeSettingsFromList settingsList updated
    in
    updated :: without


updateEmployeeList : List Employee -> Employee -> List Employee
updateEmployeeList employees updated =
    let
        without =
            removeEmployeeFromList employees updated
    in
    updated :: without


removeEmployeeFromList : List Employee -> Employee -> List Employee
removeEmployeeFromList employees toRemove =
    List.Extra.filterNot (\e -> e.id == toRemove.id) employees


updateShiftList : List Shift -> Shift -> List Shift
updateShiftList shifts updated =
    let
        without =
            removeShiftFromList shifts updated
    in
    updated :: without


removeShiftFromList : List Shift -> Shift -> List Shift
removeShiftFromList shifts toRemove =
    List.Extra.filterNot (\e -> e.id == toRemove.id) shifts

updateVacationList : List Vacation -> Vacation -> List Vacation
updateVacationList vacations updated =
    let
        without =
            removeVacationFromList vacations updated
    in
    updated :: without


removeVacationFromList : List Vacation -> Vacation -> List Vacation
removeVacationFromList vacations toRemove =
    List.Extra.filterNot (\e -> e.id == toRemove.id) vacations


sortEmployeeList : List Employee -> List Employee
sortEmployeeList employees =
    List.sortWith
        (\e1 e2 ->
            compare (nameToString e1.name FullName) (nameToString e2.name FullName)
        )
        employees


openVacationModal : Model -> CalendarData -> VacationData -> Model
openVacationModal model page modalData =
    let
        updatedPage =
            { page | modal = VacationModal modalData }
    in
    { model | page = CalendarPage updatedPage }


openShiftModal : Model -> CalendarData -> ShiftData -> Model
openShiftModal model page modalData =
    let
        updatedPage =
            { page | modal = ShiftModal modalData }
    in
    { model | page = CalendarPage updatedPage }


focusElement : String -> Cmd Message
focusElement element =
    Task.attempt
        FocusResult
        (Dom.focus element)


update : Message -> Model -> ( Model, Cmd Message )
update message model =
    case ( model.page, message ) of
        -- General messages

        ( _, CheckTokenResponse onFail onSuccess result ) ->
            case result of
                Ok _ ->
                    update onSuccess model
                Err _ ->
                    update onFail model

        ( CalendarPage page, GoToLogin ) ->
            let
                updatedModel = { model | page = LoginPage defaultLoginModel }
            in ( updatedModel, Cmd.none )

        ( LoginPage page, GoToCalendar ) ->
            let
                updatedModel = { model | page = CalendarPage defaultCalendarModel }
            in ( updatedModel, Cmd.none )

        ( _, UrlRequest request ) ->
            ( model, Cmd.none )

        ( _, UrlChanged url ) ->
            ( model, Cmd.none )

        ( _, Logout ) ->
            ( model
            , Http.post
                { url = UB.absolute [ "sched", "logout_request" ] []
                , body = Http.emptyBody
                , expect = Http.expectWhatever LogoutResponse
                }
            )

        ( _, IgnoreReply _ ) ->
            ( model, Cmd.none )

        ( _, LogoutResponse _ ) ->
            update GoToLogin model

        -- Account modal messages
        ( CalendarPage page, OpenAccountModal ) ->
            case (page.modal, model.currentEmployee) of
                (NoModal, Just currentEmployee) ->
                    let
                        modalData = AccountModalData
                            False
                            (Maybe.withDefault "" currentEmployee.phoneNumber)
                            ""
                            ""
                            ""
                            ""
                        
                        updatedPage = { page | modal = AccountModal modalData }

                        updatedModel = { model | page = CalendarPage updatedPage }
                    in (updatedModel, Cmd.none)
                    
                _ -> (model, Cmd.none)

        ( CalendarPage page, OpenDefaultColorSelector ) ->
            case page.modal of 
                AccountModal modalData ->
                    if modalData.colorSelectOpen == False then 
                        let
                            updatedData = { modalData | colorSelectOpen = True }

                            updatedPage = { page | modal = AccountModal updatedData }

                            updatedModel = { model | page = CalendarPage updatedPage }

                        in ( updatedModel, Cmd.none )
                    else ( model, Cmd.none )
                _ -> ( model, Cmd.none )

        ( CalendarPage page, UpdateAccountPhoneNumber phoneNumber ) ->
            case page.modal of
                AccountModal modalData ->
                    let
                        updatedModal = { modalData | phoneNumber = phoneNumber }
                        updatedPage = { page | modal = AccountModal updatedModal }
                        updatedModel = { model | page = CalendarPage updatedPage }
                    in ( updatedModel, Cmd.none )
                _ -> ( model, Cmd.none )

        ( CalendarPage page, AccountModalUnfocusPhoneNumber ) ->
            case (page.modal, model.currentEmployee) of
                (AccountModal modalData, Just currentEmployee) ->
                    let
                        updatedEmployee = { currentEmployee | phoneNumber = Just modalData.phoneNumber }
                        req = updateEmployee updatedEmployee
                        employees = Maybe.withDefault [] model.employees
                        updatedEmployees = updateEmployeeList employees updatedEmployee
                        updatedModel = { model | currentEmployee = Just updatedEmployee
                            , employees = Just updatedEmployees }
                    in ( updatedModel, req )
                _ -> ( model, Cmd.none )

        ( CalendarPage page, UpdateAccountDefaultColor color ) ->
            case (page.modal, model.currentEmployee) of
                (AccountModal modalData, Just currentEmployee) ->
                    let
                        colorString = colorToString color

                        updatedData = { modalData | colorSelectOpen = False
                            , status = "Changed default color to " ++ colorString }

                        updatedPage = { page | modal = AccountModal updatedData }

                        employees = Maybe.withDefault [] model.employees

                        updatedEmployee = { currentEmployee | defaultColor = color }

                        updatedEmployees = updateEmployeeList employees updatedEmployee

                        updatedModel = { model | 
                            page = CalendarPage updatedPage
                            , employees = Just updatedEmployees
                            , currentEmployee = Just updatedEmployee }

                    in ( updatedModel, updateEmployee updatedEmployee )

                _ -> ( model, Cmd.none )

        ( CalendarPage page, UpdateAccountOldPassword oldPassword ) ->
            case page.modal of
                AccountModal modalData ->
                    let
                        updatedModal = { modalData | oldPassword = oldPassword }
                        updatedPage = { page | modal = AccountModal updatedModal }
                        updatedModel = { model | page = CalendarPage updatedPage }
                    in ( updatedModel, Cmd.none )
                _ -> ( model, Cmd.none )

        ( CalendarPage page, UpdateAccountNewPassword newPassword ) ->
            case page.modal of
                AccountModal modalData ->
                    let
                        updatedModal = { modalData | newPassword = newPassword }
                        updatedPage = { page | modal = AccountModal updatedModal }
                        updatedModel = { model | page = CalendarPage updatedPage }
                    in ( updatedModel, Cmd.none )
                _ -> ( model, Cmd.none )

        ( CalendarPage page, UpdateAccountNewPasswordAgain newPasswordAgain ) ->
            case page.modal of
                AccountModal modalData ->
                    let
                        updatedModal = { modalData | newPasswordAgain = newPasswordAgain }
                        updatedPage = { page | modal = AccountModal updatedModal }
                        updatedModel = { model | page = CalendarPage updatedPage }
                    in ( updatedModel, Cmd.none )
                _ -> ( model, Cmd.none )

        ( CalendarPage page, ChangePassword ) ->
            case page.modal of
                AccountModal modalData ->
                    let 
                        match = matchPasswords modalData

                        newStatus = case match of
                            Just _ -> "Changing password"
                            Nothing -> "Passwords don't match!"

                        pwRequest =
                            case match of
                                Just _ ->
                                    Http.post
                                        { url = "/sched/change_password"
                                        , body = Http.jsonBody <| loginInfoEncoder modalData
                                        , expect = Http.expectWhatever ChangePasswordResponse
                                        }
                                _ -> Cmd.none

                        updatedModal = { modalData | status = newStatus }

                        updatedPage = { page | modal = AccountModal updatedModal }

                        updatedModel = { model | page = CalendarPage updatedPage }

                    in ( updatedModel, pwRequest )
                                    
                _ -> ( model, Cmd.none )

        ( CalendarPage page, ChangePasswordResponse response ) ->
            case page.modal of
                AccountModal modalData ->
                    let 
                        newStatus = case response of
                            Ok _ -> "Changed password!"

                            Err e -> httpErrorString e

                        updatedModal = { modalData | status = newStatus }

                        updatedPage = { page | modal = AccountModal updatedModal }

                        updatedModel = { model | page = CalendarPage updatedPage }
                    in ( updatedModel, Cmd.none )

                _ -> ( model, Cmd.none )

        ( CalendarPage page, CloseAccountModal ) ->
            case page.modal of
                AccountModal _ ->
                    let
                        updatedPage = { page | modal = NoModal }

                        updatedModel = { model | page = CalendarPage updatedPage }
                    in ( updatedModel, Cmd.none )
                _ -> ( model, Cmd.none )

        -- Login messages
        ( LoginPage page, LoginRequest ) ->
            ( model, loginRequest page.loginInfo )

        ( LoginPage page, LoginResponse r ) ->
            let
                updatedPage =
                    { page
                        | loginInfo =
                            LoginInfo "" ""
                    }

                updatedModel =
                    { model
                        | page = LoginPage updatedPage
                    }
            in
            case r of
                Ok _ ->
                    update GoToCalendar updatedModel

                Err _ ->
                    ( updatedModel, Cmd.none )

        ( LoginPage page, UpdateEmail email ) ->
            let
                info =
                    page.loginInfo

                updatedInfo =
                    { info | email = email }

                updatedPage =
                    { page | loginInfo = updatedInfo }

                updatedModel =
                    { model | page = LoginPage updatedPage }
            in
            ( updatedModel, Cmd.none )

        ( LoginPage page, UpdatePassword password ) ->
            let
                info =
                    page.loginInfo

                updatedInfo =
                    { info | password = password }

                updatedPage =
                    { page | loginInfo = updatedInfo }

                updatedModel =
                    { model | page = LoginPage updatedPage }
            in
            ( updatedModel, Cmd.none )

        -- Loading messages
        ( _, ReceiveCurrentEmployee employeeResult ) ->
            case employeeResult of
                Ok employee ->
                    let
                        updatedModel =
                            { model | currentEmployee = Just employee }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( _, ReceiveEmployees employeesResult ) ->
            case employeesResult of
                Ok employees ->
                    let
                        sortedEmps =
                            sortEmployeeList
                                employees

                        updated =
                            { model | employees = Just sortedEmps }
                    in
                    ( updated, Cmd.none )

                Err e ->
                    update GoToLogin model

        ( _, ReceiveShifts shiftsResult ) ->
            case shiftsResult of
                Ok shifts ->
                    ( { model
                        | shifts =
                            Just shifts
                      }
                    , Cmd.none
                    )

                Err e ->
                    ( model, Cmd.none )

        ( _, ReceiveVacations vacationsResult ) ->
            case vacationsResult of
                Ok vacations ->
                    ( { model
                        | vacations =
                            Just vacations
                      }
                    , Cmd.none
                    )

                Err e ->
                    ( model, Cmd.none )

        ( _, ReceiveSettingsList settingsResult ) ->
            case settingsResult of
                Ok settingsList ->
                    let
                        updated =
                            { model
                                | settingsList = Just settingsList
                            }
                    in
                    updateViewDate updated

                Err e ->
                    ( model, Cmd.none )

        ( _, ReceivePosixTime posixTime ) ->
            let
                updatedModel =
                    { model
                        | posixNow = Just posixTime
                    }
            in
            updateViewDate updatedModel

        ( _, ReceiveZone here ) ->
            let
                updatedModel =
                    { model | here = Just here }
            in
            updateViewDate updatedModel

        ( _, ReceiveDefaultSettings settingsResult ) ->
            case settingsResult of
                Ok settingsMaybe ->
                    case settingsMaybe of
                        Just settings ->
                            let
                                updated =
                                    { model | activeSettings = Just settings }
                            in
                            updateViewDate updated

                        Nothing ->
                            ( model, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        ( _, ReloadData _ ) ->
            let
                updated =
                    { model
                        | settingsList = Nothing
                        , activeSettings = Nothing
                        , currentEmployee = Nothing
                        , employees = Nothing
                        , shifts = Nothing
                        , posixNow = Nothing
                        , here = Nothing
                    }
            in
            ( model, loadData )

        -- View select messages
        ( CalendarPage page, OpenViewSelect ) ->
            case page.modal of
                NoModal ->
                    let
                        updatedPage =
                            { page
                                | modal =
                                    ViewSelectModal
                            }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, ChooseActiveView activeID ) ->
            case page.modal of
                ViewSelectModal ->
                    case getSettings model activeID of
                        Just active ->
                            ( model
                            , Http.post
                                { url = "/sched/set_default_settings"
                                , body =
                                    Http.jsonBody <|
                                        settingsEncoder active.settings
                                , expect = Http.expectWhatever ReloadData
                                }
                            )

                        Nothing ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, CloseViewSelect ) ->
            case page.modal of
                ViewSelectModal ->
                    let
                        updatedPage =
                            { page | modal = NoModal }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, RemoveView ) ->
            case getActiveSettings model of
                Just active ->
                    ( model
                    , Http.post
                        { url = "/sched/remove_settings"
                        , body = Http.jsonBody (settingsEncoder active.settings)
                        , expect = Http.expectWhatever ReloadData
                        }
                    )

                Nothing ->
                    ( model, Cmd.none )

        ( CalendarPage page, DuplicateView ) ->
            case getActiveSettings model of
                Just active ->
                    ( model
                    , Http.post
                        { url = "/sched/copy_settings"
                        , body =
                            Http.jsonBody <|
                                combinedSettingsEncoder
                                    active
                        , expect =
                            Http.expectWhatever
                                ReloadData
                        }
                    )

                Nothing ->
                    ( model, Cmd.none )

        -- View edit messages
        ( CalendarPage page, OpenViewEdit ) ->
            case ( page.modal, getActiveSettings model ) of
                ( NoModal, Just active ) ->
                    let
                        updatedPage =
                            { page
                                | modal =
                                    ViewEditModal <| defaultViewEdit active.settings
                            }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, UpdateViewName name ) ->
            case ( page.modal, getActiveSettings model ) of
                ( ViewEditModal _, Just active ) ->
                    let
                        settings =
                            active.settings

                        updatedSettings =
                            { settings | name = name }

                        updatedCombined =
                            { active | settings = updatedSettings }

                        settingsList = Maybe.withDefault [] model.settingsList

                        updatedSettingsList = updateSettingsList settingsList updatedCombined

                        updatedModel = { model | settingsList = Just updatedSettingsList }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, ViewEditUnfocusName ) ->
            case page.modal of
                ViewEditModal modalData ->
                    let
                        req = updateSettings modalData.settings
                    in ( model, req )
                _ -> ( model, Cmd.none )

        ( CalendarPage page, UpdateViewType viewType ) ->
            case ( page.modal, getActiveSettings model ) of
                ( ViewEditModal _, Just active ) ->
                    let
                        settings =
                            active.settings

                        updatedSettings =
                            { settings | viewType = viewType }
                    in
                    ( model, updateSettings updatedSettings )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, UpdateHourFormat hourFormat ) ->
            case ( page.modal, getActiveSettings model ) of
                ( ViewEditModal _, Just active ) ->
                    let
                        settings =
                            active.settings

                        updatedSettings =
                            { settings | hourFormat = hourFormat }
                    in
                    ( model, updateSettings updatedSettings )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, UpdateLastNameStyle lastNameStyle ) ->
            case ( page.modal, getActiveSettings model ) of
                ( ViewEditModal _, Just active ) ->
                    let
                        settings =
                            active.settings

                        updatedSettings =
                            { settings | lastNameStyle = lastNameStyle }
                    in
                    ( model, updateSettings updatedSettings )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, UpdateShowMinutes show ) ->
            case ( page.modal, getActiveSettings model ) of
                ( ViewEditModal data, Just active ) ->
                    let
                        settings =
                            active.settings

                        updatedSettings =
                            { settings | showMinutes = show }
                    in
                    ( model, updateSettings updatedSettings )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, UpdateShowShifts show ) ->
            case ( page.modal, getActiveSettings model ) of
                ( ViewEditModal data, Just active ) ->
                    let
                        settings =
                            active.settings

                        updatedSettings =
                            { settings | showShifts = show }
                    in
                    ( model, updateSettings updatedSettings )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, UpdateShowCallShifts show ) ->
            case ( page.modal, getActiveSettings model ) of
                ( ViewEditModal data, Just active ) ->
                    let
                        settings =
                            active.settings

                        updatedSettings =
                            { settings | showCallShifts = show }
                    in
                    ( model, updateSettings updatedSettings )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, UpdateShowVacations show ) ->
            case ( page.modal, getActiveSettings model ) of
                ( ViewEditModal data, Just active ) ->
                    let
                        settings =
                            active.settings

                        updatedSettings =
                            { settings | showVacations = show }
                    in
                    ( model, updateSettings updatedSettings )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, EmployeeViewCheckbox id checked ) ->
            case ( page.modal, getActiveSettings model ) of
                ( ViewEditModal _, Just active ) ->
                    let
                        settings =
                            active.settings

                        viewEmployees =
                            settings.viewEmployees

                        updatedEmployees =
                            case checked of
                                True ->
                                    id :: viewEmployees |> List.Extra.unique

                                False ->
                                    List.Extra.remove id viewEmployees

                        updatedSettings =
                            { settings | viewEmployees = updatedEmployees }
                    in
                    ( model, updateSettings updatedSettings )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, OpenEmployeeColorSelector employee ) ->
            case page.modal of
                ViewEditModal editData ->
                    let
                        updatedData =
                            { editData | colorSelect = Just employee }

                        updatedPage =
                            { page | modal = ViewEditModal updatedData }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, ChooseEmployeeColor employee color ) ->
            case
                ( page.modal
                , getEmployeeSettings model (Just employee.id)
                , getActiveSettings model
                )
            of
                ( ViewEditModal editData, Just perEmployee, _ ) ->
                    let
                        updatedData =
                            { editData | colorSelect = Nothing }

                        updatedPage =
                            { page | modal = ViewEditModal updatedData }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }

                        updatedPerEmployee =
                            { perEmployee | color = color }
                    in
                    ( updatedModel
                    , Http.post
                        { url = "/sched/update_employee_settings"
                        , body =
                            Http.jsonBody
                                (perEmployeeSettingsEncoder updatedPerEmployee)
                        , expect = Http.expectWhatever ReloadData
                        }
                    )

                ( ViewEditModal editData, Nothing, Just active ) ->
                    let
                        updatedData =
                            { editData | colorSelect = Nothing }

                        updatedPage =
                            { page | modal = ViewEditModal updatedData }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }

                        perEmployee =
                            PerEmployeeSettings
                                0
                                active.settings.id
                                employee.id
                                color
                    in
                    ( updatedModel
                    , Http.post
                        { url = "/sched/add_employee_settings"
                        , body =
                            Http.jsonBody
                                (perEmployeeSettingsEncoder perEmployee)
                        , expect = Http.expectWhatever ReloadData
                        }
                    )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, CloseViewEdit ) ->
            case page.modal of
                ViewEditModal editData ->
                    let
                        updatedPage =
                            { page | modal = NoModal }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        -- Event Modal messages
        ( CalendarPage page, OpenAddEvent day ) ->
            case page.modal of
                NoModal ->
                    let
                        updatedPage =
                            { page | modal = AddEventModal day }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, CancelAddEvent ) ->
            case page.modal of
                AddEventModal _ ->
                    let
                        updatedPage =
                            { page | modal = NoModal }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, CreateShiftResponse shiftResult ) ->
            case ( page.modal, shiftResult, getActiveSettings model ) of
                ( AddEventModal day, Ok shift, Just active ) ->
                    let
                        employees =
                            Maybe.withDefault [] model.employees

                        viewEmployees =
                            getViewEmployees
                                employees
                                active.settings.viewEmployees

                        shiftEmployee =
                            getEmployee
                                viewEmployees
                                shift.employeeID

                        modalData =
                            ShiftData
                                True
                                shift
                                shiftEmployee
                                ""
                                viewEmployees
                                day
                                (Maybe.withDefault "" shift.note)

                        updatedModel =
                            openShiftModal
                                model
                                page
                                modalData
                    in
                    ( updatedModel
                    , Cmd.batch
                        [ focusElement "employeeSearch"
                        , loadData
                        ]
                    )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, CreateShiftRequest ymd ) ->
            case page.modal of
                AddEventModal _ ->
                    let
                        newShift = Shift
                            0
                            0
                            Nothing
                            ymd.year
                            ymd.month
                            ymd.day
                            8
                            0
                            8
                            0
                            NeverRepeat
                            (Just 1)
                            Nothing
                            False
                    in
                    ( model
                    , Http.post
                        { url = "/sched/add_shift"
                        , body =
                            Http.jsonBody
                                <| shiftEncoder newShift
                        , expect = Http.expectJson CreateShiftResponse shiftDecoder
                        }
                    )

                _ ->
                    ( model, Cmd.none )


        ( CalendarPage page, CreateCallShiftResponse shiftResult ) ->
            case ( page.modal, shiftResult, getActiveSettings model ) of
                ( AddEventModal day, Ok shift, Just active ) ->
                    let
                        employees =
                            Maybe.withDefault [] model.employees

                        viewEmployees =
                            getViewEmployees
                                employees
                                active.settings.viewEmployees

                        shiftEmployee =
                            getEmployee
                                viewEmployees
                                shift.employeeID

                        modalData =
                            ShiftData
                                True
                                shift
                                shiftEmployee
                                ""
                                viewEmployees
                                day
                                (Maybe.withDefault "" shift.note)

                        updatedModel =
                            openShiftModal
                                model
                                page
                                modalData
                    in
                    ( updatedModel
                    , Cmd.batch
                        [ focusElement "employeeSearch"
                        , loadData
                        ]
                    )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, CreateCallShiftRequest ymd ) ->
            case page.modal of
                AddEventModal _ ->
                    let
                        newShift = Shift
                            0
                            0
                            Nothing
                            ymd.year
                            ymd.month
                            ymd.day
                            8
                            0
                            8
                            0
                            NeverRepeat
                            (Just 1)
                            Nothing
                            True
                    in
                    ( model
                    , Http.post
                        { url = "/sched/add_shift"
                        , body =
                            Http.jsonBody
                                <| shiftEncoder newShift
                        , expect = Http.expectJson CreateCallShiftResponse shiftDecoder
                        }
                    )

                _ ->
                    ( model, Cmd.none )


        ( CalendarPage page, OpenShiftModal modalData ) ->
            case page.modal of
                NoModal ->
                    ( openShiftModal
                        model
                        page
                        modalData
                    , Cmd.batch
                        [ focusElement "employeeSearch"
                        , loadData
                        ]
                    )

                AddEventModal day ->
                    ( openShiftModal
                        model
                        page
                        modalData
                    , Cmd.batch
                        [ focusElement "employeeSearch"
                        , loadData
                        ]
                    )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, OpenVacationModal modalData ) ->
            case page.modal of
                NoModal ->
                    ( openVacationModal
                        model
                        page
                        modalData
                    , loadData
                    )

                AddEventModal day ->
                    ( openVacationModal
                        model
                        page
                        modalData
                    , loadData
                    )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, CreateVacationResponse vacationResult ) ->
            case ( page.modal, vacationResult, getActiveSettings model ) of
                ( AddEventModal day, Ok vacation, Just active ) ->
                    let
                        modalData =
                            VacationData
                                True
                                vacation
                                day

                        updatedModel =
                            openVacationModal
                                model
                                page
                                modalData
                    in
                    ( updatedModel, loadData )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, CreateVacationRequest day ) ->
            case ( page.modal, model.currentEmployee ) of
                ( AddEventModal _, Just currentEmployee ) ->
                    case ( model.posixNow, model.here ) of
                        ( Just now, Just here ) ->
                            let
                                today =
                                    getTime now here
                            in
                            ( model
                            , Http.post
                                { url = "/sched/add_vacation"
                                , body =
                                    Http.jsonBody
                                        (vacationEncoder <|
                                            Vacation
                                                0
                                                Nothing
                                                currentEmployee.id
                                                False
                                                day.year
                                                day.month
                                                day.day
                                                (Just 1)
                                                today.year
                                                today.month
                                                today.day
                                        )
                                , expect = Http.expectJson CreateVacationResponse vacationDecoder
                                }
                            )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, EventToggleEdit ) ->
            case page.modal of
                ShiftModal modalData ->
                    let
                        updatedData =
                            { modalData | editEnabled = not modalData.editEnabled }

                        updatedPage =
                            { page | modal = ShiftModal updatedData }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, Cmd.none )

                VacationModal modalData ->
                    let
                        updatedData =
                            { modalData | editEnabled = not modalData.editEnabled }

                        updatedPage =
                            { page | modal = VacationModal updatedData }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, UpdateVacationSupervisor supervisor ) ->
            case page.modal of
                VacationModal modalData ->
                    case ( model.posixNow, model.here ) of
                        ( Just now, Just here ) ->
                            let
                                vacation =
                                    modalData.vacation

                                today =
                                    getTime now here

                                updatedVacation =
                                    { vacation
                                        | supervisorID = Just supervisor.id
                                        , approved = False
                                        , requestYear = today.year
                                        , requestMonth = today.month
                                        , requestDay = today.day
                                    }

                                updatedData =
                                    { modalData | vacation = updatedVacation }

                                updatedPage =
                                    { page | modal = VacationModal updatedData }

                                updatedModel =
                                    { model | page = CalendarPage updatedPage }
                            in
                            ( updatedModel, updateVacation updatedVacation )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, UpdateVacationDuration days ) ->
            case page.modal of
                VacationModal modalData ->
                    let
                        vacation =
                            modalData.vacation

                        updatedVacation =
                            { vacation | durationDays = String.toInt days
                                , approved = False }

                        updatedData =
                            { modalData | vacation = updatedVacation }

                        updatedPage =
                            { page | modal = VacationModal updatedData }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, updateVacation updatedVacation )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, CloseEventModal ) ->
            case page.modal of
                ShiftModal _ ->
                    let
                        updatedPage =
                            { page | modal = NoModal }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, Cmd.none )

                VacationModal _ ->
                    let
                        updatedPage =
                            { page | modal = NoModal }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, ShiftEmployeeSearch searchText ) ->
            case ( page.modal, getActiveSettings model ) of
                ( ShiftModal modalData, Just active ) ->
                    let
                        viewEmployees =
                            getViewEmployees
                                (Maybe.withDefault [] model.employees)
                                active.settings.viewEmployees

                        newMatches =
                            Fuzzy.filter
                                (\emp -> nameToString emp.name FullName)
                                searchText
                                viewEmployees

                        updatedModal =
                            { modalData
                                | employeeSearch = searchText
                                , employeeMatches = newMatches
                            }

                        updatedPage =
                            { page | modal = ShiftModal updatedModal }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    if List.length newMatches == 1 then
                        case List.head newMatches of
                            Just oneEmp ->
                                update
                                    (ChooseShiftEmployee oneEmp)
                                    updatedModel

                            Nothing ->
                                ( updatedModel, Cmd.none )

                    else
                        ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, ChooseShiftEmployee employee ) ->
            case page.modal of
                ShiftModal modalData ->
                    let
                        shift =
                            modalData.shift

                        updatedShift =
                            { shift | employeeID = Just employee.id }

                        updatedData =
                            { modalData
                                | employee = Just employee
                                , shift = updatedShift
                            }

                        updatedPage =
                            { page | modal = ShiftModal updatedData }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, updateShift updatedShift )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, ShiftEditUpdateNote note ) ->
            case page.modal of
                ShiftModal modalData ->
                    let
                        updatedModal = { modalData | note = note }
                        updatedPage = { page | modal = ShiftModal updatedModal }
                        updatedModel = { model | page = CalendarPage updatedPage }
                    in ( updatedModel, Cmd.none )
                _ -> ( model, Cmd.none )

        ( CalendarPage page, ShiftEditUnfocusNote ) ->
            case page.modal of
                ShiftModal modalData ->
                    let
                        shift =
                            modalData.shift

                        updatedShift =
                            { shift | note = Just modalData.note }

                        shifts = Maybe.withDefault [] model.shifts

                        updatedShifts = updateShiftList shifts updatedShift

                        updatedData =
                            { modalData | shift = updatedShift }

                        updatedPage =
                            { page | modal = ShiftModal updatedData }

                        updatedModel =
                            { model | page = CalendarPage updatedPage 
                                , shifts = Just updatedShifts }
                    in
                    ( updatedModel, updateShift updatedShift )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, UpdateShiftRepeat shiftRepeat ) ->
            case page.modal of
                ShiftModal modalData ->
                    let
                        shift =
                            modalData.shift

                        updatedShift =
                            { shift | repeat = shiftRepeat }

                        updatedData =
                            { modalData | shift = updatedShift }

                        updatedPage =
                            { page | modal = ShiftModal updatedData }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, updateShift updatedShift )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, UpdateShiftRepeatRate rateStr ) ->
            case ( page.modal, String.toInt rateStr ) of
                ( ShiftModal modalData, rate ) ->
                    let
                        shift =
                            modalData.shift

                        updatedShift =
                            { shift | everyX = rate }

                        updatedData =
                            { modalData | shift = updatedShift }

                        updatedPage =
                            { page | modal = ShiftModal updatedData }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, updateShift updatedShift )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, UpdateShiftStart f ) ->
            case page.modal of
                ShiftModal modalData ->
                    let
                        shift =
                            modalData.shift

                        updatedShift =
                            { shift
                                | hour = floatToHour f
                                , minute = floatToQuarterHour f
                            }

                        updatedData =
                            { modalData | shift = updatedShift }

                        updatedPage =
                            { page | modal = ShiftModal updatedData }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, updateShift updatedShift )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, UpdateShiftDuration f ) ->
            case page.modal of
                ShiftModal modalData ->
                    let
                        shift =
                            modalData.shift

                        updatedShift =
                            { shift
                                | hours = floatToHour f
                                , minutes = floatToQuarterHour f
                            }

                        updatedData =
                            { modalData | shift = updatedShift }

                        updatedPage =
                            { page | modal = ShiftModal updatedData }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, updateShift updatedShift )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, UpdateShiftOnCall onCall ) ->
            case page.modal of
                ShiftModal modalData ->
                    let
                        shift = modalData.shift
                        updatedShift = { shift | onCall = onCall }
                        shifts = Maybe.withDefault [] model.shifts
                        updatedShifts = updateShiftList shifts updatedShift
                        updateReq = updateShift updatedShift
                        updatedModal = { modalData | shift = updatedShift }
                        updatedPage = { page | modal = ShiftModal updatedModal }
                        updatedModel = { model | shifts = Just updatedShifts
                            , page = CalendarPage updatedPage }
                    in ( updatedModel, updateReq)
                _ -> ( model, Cmd.none )

        ( CalendarPage page, RemoveEventAndClose event ) ->
            let
                updatedPage =
                    { page | modal = NoModal }

                updatedModel =
                    { model | page = CalendarPage updatedPage }
            in
            case event of
                ShiftEvent shift ->
                    ( updatedModel
                    , Http.post
                        { url = "/sched/remove_shift"
                        , body = Http.jsonBody (shiftEncoder shift)
                        , expect = Http.expectWhatever ReloadData
                        }
                    )

                VacationEvent vacation ->
                    ( updatedModel
                    , Http.post
                        { url = "/sched/remove_vacation"
                        , body = Http.jsonBody (vacationEncoder vacation)
                        , expect = Http.expectWhatever ReloadData
                        }
                    )

        -- Employee Editor Messages
        ( CalendarPage page, OpenEmployeeEditor ) ->
            case page.modal of
                NoModal ->
                    let
                        viewEmployees =
                            Maybe.withDefault [] model.employees

                        editData =
                            EmployeeEditData
                                ""
                                viewEmployees
                                (case viewEmployees of
                                    [ one ] ->
                                        Just one

                                    _ ->
                                        Nothing
                                )
                                ""

                        updatedPage =
                            { page | modal = EmployeeEditor editData }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, CloseEmployeeEditor ) ->
            case page.modal of
                EmployeeEditor _ ->
                    let
                        updatedPage =
                            { page | modal = NoModal }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, EmployeeEditNewEmployee ) ->
            case page.modal of
                EmployeeEditor editData ->
                    let
                        newEmployee =
                            Employee
                                0
                                "email@address.com"
                                Nothing
                                Read
                                (Name "New" "Employee")
                                (Just "(555) 123-4567")
                                Green
                    in
                    ( model
                    , Http.post
                        { url = "/sched/add_employee"
                        , body = Http.jsonBody <| employeeEncoder newEmployee
                        , expect = Http.expectJson EmployeeEditGetNewEmployee employeeDecoder
                        }
                    )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, EmployeeEditGetNewEmployee employeeResult ) ->
            case ( page.modal, employeeResult ) of
                ( EmployeeEditor editData, Ok employee ) ->
                    let
                        employees =
                            Maybe.withDefault [] model.employees

                        updatedEmployees =
                            updateEmployeeList employees employee

                        sortedEmployees =
                            sortEmployeeList updatedEmployees

                        updatedData =
                            { editData
                                | employee = Just employee
                                , filteredEmployees =
                                    Fuzzy.filter
                                        (\emp -> nameToString emp.name FullName)
                                        editData.employeeSearchText
                                        sortedEmployees
                            }

                        updatedPage =
                            { page | modal = EmployeeEditor updatedData }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    update (ReloadData (Ok ())) updatedModel

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, UpdateEmployeeEditorSearch searchText ) ->
            case ( page.modal, getActiveSettings model ) of
                ( EmployeeEditor editData, Just active ) ->
                    let
                        viewEmployees =
                            getViewEmployees
                                (Maybe.withDefault [] model.employees)
                                active.settings.viewEmployees

                        filteredEmployees =
                            Fuzzy.filter
                                (\emp -> nameToString emp.name FullName)
                                searchText
                                viewEmployees

                        updatedData =
                            { editData
                                | employeeSearchText = searchText
                                , filteredEmployees = filteredEmployees
                                , employee =
                                    case filteredEmployees of
                                        [ one ] ->
                                            Just one

                                        _ ->
                                            Nothing
                            }

                        updatedPage =
                            { page
                                | modal = EmployeeEditor updatedData
                            }

                        updatedModel =
                            { model
                                | page = CalendarPage updatedPage
                            }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, EmployeeEditorChooseEmployee employee ) ->
            case page.modal of
                EmployeeEditor editData ->
                    let
                        updatedData =
                            { editData | employee = Just employee }

                        updatedPage =
                            { page | modal = EmployeeEditor updatedData }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, EmployeeEditRemoveEmployee ) ->
            case page.modal of
                EmployeeEditor editData ->
                    case editData.employee of
                        Just employee ->
                            let
                                updatedData =
                                    { editData
                                        | employee = Nothing
                                        , filteredEmployees =
                                            removeEmployeeFromList editData.filteredEmployees employee
                                    }

                                updatedPage =
                                    { page | modal = EmployeeEditor updatedData }

                                updatedModel =
                                    { model | page = CalendarPage updatedPage }
                            in
                            ( updatedModel
                            , Http.post
                                { url = "/sched/remove_employee"
                                , body = Http.jsonBody <| employeeEncoder employee
                                , expect = Http.expectWhatever ReloadData
                                }
                            )

                        Nothing ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, EmployeeEditUpdateEmail email ) ->
            case page.modal of
                EmployeeEditor editData ->
                    case editData.employee of
                        Just employee ->
                            let
                                updatedEmployee =
                                    { employee | email = email }

                                employees =
                                    Maybe.withDefault [] model.employees

                                updatedEmployees =
                                    updateEmployeeList employees updatedEmployee

                                sortedEmployees =
                                    sortEmployeeList updatedEmployees

                                updatedData =
                                    { editData
                                        | employee = Just updatedEmployee
                                        , filteredEmployees =
                                            Fuzzy.filter
                                                (\emp -> nameToString emp.name FullName)
                                                editData.employeeSearchText
                                                sortedEmployees
                                    }

                                updatedPage =
                                    { page | modal = EmployeeEditor updatedData }

                                updatedModel =
                                    { model
                                        | page = CalendarPage updatedPage
                                        , employees = Just updatedEmployees
                                    }
                            in
                            ( updatedModel, updateEmployee updatedEmployee )

                        Nothing ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, EmployeeEditUpdateFirstName first ) ->
            case page.modal of
                EmployeeEditor editData ->
                    case editData.employee of
                        Just employee ->
                            let
                                name =
                                    employee.name

                                updatedName =
                                    { name | first = first }

                                updatedEmployee =
                                    { employee | name = updatedName }

                                employees =
                                    Maybe.withDefault [] model.employees

                                updatedEmployees =
                                    updateEmployeeList employees updatedEmployee

                                sortedEmployees =
                                    sortEmployeeList updatedEmployees

                                updatedData =
                                    { editData
                                        | employee = Just updatedEmployee
                                        , filteredEmployees =
                                            Fuzzy.filter
                                                (\emp -> nameToString emp.name FullName)
                                                editData.employeeSearchText
                                                sortedEmployees
                                    }

                                updatedPage =
                                    { page | modal = EmployeeEditor updatedData }

                                updatedModel =
                                    { model | page = CalendarPage updatedPage }
                            in
                            ( updatedModel, updateEmployee updatedEmployee )

                        Nothing ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, EmployeeEditUpdateLastName last ) ->
            case page.modal of
                EmployeeEditor editData ->
                    case editData.employee of
                        Just employee ->
                            let
                                name =
                                    employee.name

                                updatedName =
                                    { name | last = last }

                                updatedEmployee =
                                    { employee | name = updatedName }

                                employees =
                                    Maybe.withDefault [] model.employees

                                updatedEmployees =
                                    updateEmployeeList employees updatedEmployee

                                sortedEmployees =
                                    sortEmployeeList updatedEmployees

                                updatedData =
                                    { editData
                                        | employee = Just updatedEmployee
                                        , filteredEmployees =
                                            Fuzzy.filter
                                                (\emp -> nameToString emp.name FullName)
                                                editData.employeeSearchText
                                                sortedEmployees
                                    }

                                updatedPage =
                                    { page | modal = EmployeeEditor updatedData }

                                updatedModel =
                                    { model | page = CalendarPage updatedPage }
                            in
                            ( updatedModel, updateEmployee updatedEmployee )

                        Nothing ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, EmployeeEditUpdatePhoneNumber phoneNumber ) ->
            case page.modal of
                EmployeeEditor editData ->
                    case editData.employee of
                        Just employee ->
                            let
                                updatedEmployee =
                                    { employee | phoneNumber = Just phoneNumber }

                                employees =
                                    Maybe.withDefault [] model.employees

                                updatedEmployees =
                                    updateEmployeeList employees updatedEmployee

                                sortedEmployees =
                                    sortEmployeeList updatedEmployees

                                updatedData =
                                    { editData
                                        | employee = Just updatedEmployee
                                        , filteredEmployees =
                                            Fuzzy.filter
                                                (\emp -> nameToString emp.name FullName)
                                                editData.employeeSearchText
                                                sortedEmployees
                                    }

                                updatedPage =
                                    { page | modal = EmployeeEditor updatedData }

                                updatedModel =
                                    { model | page = CalendarPage updatedPage }
                            in
                            ( updatedModel, updateEmployee updatedEmployee )

                        Nothing ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        -- Vacation Approval Messages
        ( CalendarPage page, OpenVacationApprovalModal ) ->
            case page.modal of
                NoModal ->
                    let
                        updatedPage =
                            { page | modal = VacationApprovalModal }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ( CalendarPage page, UpdateVacationApproval vacation approved ) ->
            let
                updatedVacation =
                    { vacation | approved = approved }

                vacations =
                    Maybe.withDefault [] model.vacations

                updatedVacationList =
                    updateVacationList vacations updatedVacation

                updatedModel =
                    { model | vacations = Just updatedVacationList }
            in
            ( updatedModel, updateVacationApproval updatedVacation )

        ( CalendarPage page, CloseVacationApprovalModal ) ->
            case page.modal of
                VacationApprovalModal ->
                    let
                        updatedPage =
                            { page | modal = NoModal }

                        updatedModel =
                            { model | page = CalendarPage updatedPage }
                    in
                    ( updatedModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        -- Calendar messages
        ( CalendarPage page, KeyDown maybeKey ) ->
            ( model, Cmd.none )

        ( CalendarPage page, PriorMonth ) ->
            case getActiveSettings model of
                Just active ->
                    let
                        settings =
                            active.settings
                    in
                    ( model
                    , Http.post
                        { url = "/sched/update_settings"
                        , body =
                            Http.jsonBody <|
                                settingsEncoder
                                    { settings
                                        | viewDate = ymdPriorMonth settings.viewDate
                                    }
                        , expect = Http.expectWhatever ReloadData
                        }
                    )

                Nothing ->
                    ( model, Cmd.none )

        ( CalendarPage page, NextMonth ) ->
            case getActiveSettings model of
                Just active ->
                    let
                        settings =
                            active.settings
                    in
                    ( model
                    , Http.post
                        { url = "/sched/update_settings"
                        , body =
                            Http.jsonBody <|
                                settingsEncoder
                                    { settings
                                        | viewDate = ymdNextMonth settings.viewDate
                                    }
                        , expect = Http.expectWhatever ReloadData
                        }
                    )

                Nothing ->
                    ( model, Cmd.none )

        ( CalendarPage page, PriorWeek ) ->
            case getActiveSettings model of
                Just active ->
                    let
                        settings =
                            active.settings
                    in
                    ( model
                    , Http.post
                        { url = "/sched/update_settings"
                        , body =
                            Http.jsonBody <|
                                settingsEncoder
                                    { settings
                                        | viewDate = addDaysToDate settings.viewDate -7
                                    }
                        , expect = Http.expectWhatever ReloadData
                        }
                    )

                Nothing ->
                    ( model, Cmd.none )

        ( CalendarPage page, NextWeek ) ->
            case getActiveSettings model of
                Just active ->
                    let
                        settings =
                            active.settings
                    in
                    ( model
                    , Http.post
                        { url = "/sched/update_settings"
                        , body =
                            Http.jsonBody <|
                                settingsEncoder
                                    { settings
                                        | viewDate = addDaysToDate settings.viewDate 7
                                    }
                        , expect = Http.expectWhatever ReloadData
                        }
                    )

                Nothing ->
                    ( model, Cmd.none )

        ( CalendarPage page, PriorDay ) ->
            case getActiveSettings model of
                Just active ->
                    let
                        settings =
                            active.settings
                    in
                    ( model
                    , Http.post
                        { url = "/sched/update_settings"
                        , body =
                            Http.jsonBody <|
                                settingsEncoder
                                    { settings
                                        | viewDate = addDaysToDate settings.viewDate -1
                                    }
                        , expect = Http.expectWhatever ReloadData
                        }
                    )

                Nothing ->
                    ( model, Cmd.none )

        ( CalendarPage page, NextDay ) ->
            case getActiveSettings model of
                Just active ->
                    let
                        settings =
                            active.settings
                    in
                    ( model
                    , Http.post
                        { url = "/sched/update_settings"
                        , body =
                            Http.jsonBody <|
                                settingsEncoder
                                    { settings
                                        | viewDate = addDaysToDate settings.viewDate 1
                                    }
                        , expect = Http.expectWhatever ReloadData
                        }
                    )

                Nothing ->
                    ( model, Cmd.none )

        ( _, _ ) ->
            ( model, Cmd.none )



-- VIEW

dividerBar : Color -> Element Message
dividerBar color =
    el
        [ fillX
        , paddingXY 0 5
        ]
        <| el 
            [ paddingXY 5 0
            , fillX
            , Border.widthEach
                { top = 2
                , bottom = 0
                , right = 0
                , left = 0
                }
            , Border.color color
            ]
            none


toDocument : Element Message -> Browser.Document Message
toDocument rootElement =
    { title = "Scheduler"
    , body =
        [ layoutWith
            { options =
                [-- focusStyle
                 -- {
                 --   borderColor = Nothing,
                 --   backgroundColor = Nothing,
                 --   shadow = Nothing
                 -- }
                ]
            }
            [ Font.family
                [ Font.typeface "Open Sans"
                , Font.sansSerif
                ]
            ]
            rootElement
        ]
    }


selectViewButton =
    Input.button
        [ defaultShadow
        , padding 5
        ]
        { onPress = Just OpenViewSelect
        , label = text "Select View"
        }


editViewButton =
    Input.button
        [ defaultShadow
        , padding 5
        ]
        { onPress = Just OpenViewEdit
        , label = text "Edit View"
        }


editEmployeesButton : Maybe Employee -> Element Message
editEmployeesButton maybeEmployee =
    case maybeEmployee of
        Just employee ->
            case employee.level of
                Admin ->
                    Input.button
                        [ defaultShadow
                        , padding 5
                        ]
                        { onPress = Just OpenEmployeeEditor
                        , label = text "Employees"
                        }

                _ ->
                    none

        Nothing ->
            none


viewLogoutButton =
    Input.button
        [ defaultShadow
        , padding 5
        ]
        { onPress = Just Logout
        , label = text "Log out"
        }


employeeEditorEmployeeOption : Employee -> Input.Option Employee Message
employeeEditorEmployeeOption employee =
    Input.optionWith employee
        (\optionState ->
            case optionState of
                Input.Selected ->
                    el
                        ([ defaultShadow, BG.color white, padding 5 ] ++ defaultBorder)
                    <|
                        text <|
                            nameToString employee.name FullName

                _ ->
                    el
                        ([ BG.color modalColor, padding 5 ] ++ defaultBorder)
                    <|
                        text <|
                            nameToString employee.name FullName
        )


viewEmployeeEditor : Model -> EmployeeEditData -> Element Message
viewEmployeeEditor model editData =
    modalOverlay CloseEmployeeEditor <|
        column
            ([ defaultShadow, centerX, centerY, BG.color modalColor ] ++ defaultBorder)
            [ el [ fillX, padding 10 ] <| el [ fillX, padding 5, BG.color white ] <| el [ centerX, headerFontSize ] <| text "Employee Editor"

            -- employees list/search
            , el [ padding 10 ] <|
                searchRadio
                    "employeeEditorSearch"
                    "Filter employees:"
                    editData.employeeSearchText
                    UpdateEmployeeEditorSearch
                    (case editData.employee of
                        Just employee ->
                            column
                                [ padding 5
                                , BG.color white
                                , Border.color green
                                , Border.width 1
                                , Border.rounded 3
                                , width <| px 300
                                , spacing 5
                                ]
                                [ Input.text
                                    []
                                    { onChange = EmployeeEditUpdateEmail
                                    , text = employee.email
                                    , placeholder = Nothing
                                    , label = Input.labelAbove [] <| text "Email:"
                                    }
                                , Input.text
                                    []
                                    { onChange = EmployeeEditUpdateFirstName
                                    , text = employee.name.first
                                    , placeholder = Nothing
                                    , label = Input.labelAbove [] <| text "First name:"
                                    }
                                , Input.text
                                    []
                                    { onChange = EmployeeEditUpdateLastName
                                    , text = employee.name.last
                                    , placeholder = Nothing
                                    , label = Input.labelAbove [] <| text "Last name:"
                                    }
                                , Input.text
                                    []
                                    { onChange = EmployeeEditUpdatePhoneNumber
                                    , text = Maybe.withDefault "" employee.phoneNumber
                                    , placeholder = Nothing
                                    , label = Input.labelAbove [] <| text "Phone number:"
                                    }
                                , el [ fillX ] <|
                                    Input.button
                                        [ padding 5, BG.color red, centerX ]
                                        { onPress = Just EmployeeEditRemoveEmployee
                                        , label = text "Delete"
                                        }
                                ]

                        Nothing ->
                            none
                    )
                    EmployeeEditorChooseEmployee
                    editData.employee
                    "Employees:"
                    (List.map employeeEditorEmployeeOption editData.filteredEmployees)
            , row [ fillX, padding 10, spacing 25 ]
                [ Input.button
                    [ centerX ]
                    { onPress = Just EmployeeEditNewEmployee
                    , label =
                        el [ padding 5, BG.color green ] <|
                            text "New employee"
                    }
                ]
            ]


vacationStartsByDate : YearMonthDay -> Vacation -> Bool
vacationStartsByDate day vacation =
    let
        _ =
            day

        start =
            vacationStartDate vacation
    in
    case dayCompare start day of
        LT ->
            False

        _ ->
            True


vacationApprovalCheckbox : Model -> Vacation -> Element Message
vacationApprovalCheckbox model vacation =
    let
        start =
            vacationStartDate vacation

        durationDays =
            Maybe.withDefault 1 vacation.durationDays

        end =
            addDaysToDate start durationDays

        dateFormat =
            Just <| YMDStringSettings ShortDate False

        startStr =
            ymdToString start dateFormat

        endStr =
            ymdToString end dateFormat

        dateRangeStr =
            startStr ++ " to " ++ endStr

        maybeActive =
            getActiveSettings model

        nameStyle =
            case maybeActive of
                Just active ->
                    active.settings.lastNameStyle

                Nothing ->
                    FullName

        employees =
            Maybe.withDefault [] model.employees

        requesterName =
            case getEmployee employees (Just vacation.employeeID) of
                Just requester ->
                    requester.name

                Nothing ->
                    Name "Unknown" ""

        requesterNameStr =
            nameToString requesterName nameStyle
    in
    Input.checkbox
        []
        { onChange = UpdateVacationApproval vacation
        , icon = Input.defaultCheckbox
        , checked = vacation.approved
        , label =
            Input.labelRight
                ([ fillX
                 , padding 5
                 ]
                    ++ defaultBorder
                )
            <|
                row
                    []
                    [ text dateRangeStr
                    , text " - "
                    , text requesterNameStr
                    ]
        }


currentEmployeeSupervisesVacation : Int -> Vacation -> Bool
currentEmployeeSupervisesVacation currentEmployeeID vacation =
    case vacation.supervisorID of
        Just supervisorID ->
            supervisorID == currentEmployeeID

        Nothing ->
            False


vacationApprovalModal : Model -> Element Message
vacationApprovalModal model =
    case ( model.posixNow, model.here ) of
        ( Just now, Just here ) ->
            let
                vacations =
                    Maybe.withDefault [] model.vacations

                today =
                    getTime now here

                currentEmployeeID =
                    case model.currentEmployee of
                        Just employee ->
                            employee.id

                        Nothing ->
                            -1

                filtered =
                    List.filter (vacationStartsByDate today) vacations
                        |> List.filter (currentEmployeeSupervisesVacation currentEmployeeID)

                sorted =
                    List.sortWith
                        (\v1 v2 ->
                            let
                                d1 =
                                    vacationRequestDate v1

                                d2 =
                                    vacationRequestDate v2
                            in
                            dayCompare d1 d2
                        )
                        filtered
            in
            modalOverlay CloseVacationApprovalModal <|
                el
                    ([ centerX
                     , centerY
                     , BG.color modalColor
                     , padding 10
                     ]
                        ++ defaultBorder
                    )
                <|
                    column
                        []
                        [ el
                            [ BG.color white
                            , headerFontSize
                            , padding 10
                            , fillX
                            ]
                          <|
                            el [ centerX ] <|
                                text "Vacation Requests"
                        , case sorted of
                            [] ->
                                el [ centerX ] <| text "No vacations to view"

                            _ ->
                                column
                                    ([ padding 5
                                     ]
                                        ++ defaultBorder
                                    )
                                <|
                                    List.map (vacationApprovalCheckbox model) sorted
                        ]

        _ ->
            text "Loading..."


openVacationsButton : Maybe Employee -> Element Message
openVacationsButton maybeEmployee =
    case maybeEmployee of
        Just employee ->
            case employee.level of
                Supervisor ->
                    Input.button
                        [ defaultShadow, padding 5 ]
                        { onPress = Just OpenVacationApprovalModal
                        , label = text "Vacations"
                        }

                _ ->
                    none

        Nothing ->
            none

openAccountModal : String -> Element Message
openAccountModal empName =
    Input.button
        [ defaultShadow, padding 5 ]
        { onPress = Just OpenAccountModal
        , label = text empName
        }



viewCalendarFooter : Maybe Employee -> Element Message
viewCalendarFooter maybeEmployee =
    let
        empName =
            case maybeEmployee of
                Just employee ->
                    nameToString employee.name FullName

                Nothing ->
                    "Loading..."
    in
    row
        [ height (px 32)
        , width fill
        , Border.solid
        , Border.color (rgb 1 1 1)
        , Border.width 1
        , spacing 15
        ]
        [ selectViewButton
        , editViewButton
        , editEmployeesButton maybeEmployee
        , openVacationsButton maybeEmployee
        , openAccountModal empName
        , viewLogoutButton
        ]


viewLogin : Model -> Element Message
viewLogin model =
    case model.page of
        LoginPage page ->
            column
                [ padding 100
                , width fill
                , BG.color (rgb 0.85 0.9 0.95)
                , centerY
                ]
                [ column
                    [ centerX
                    ]
                    [ el
                        [ alignRight
                        , width (px 300)
                        , padding 15
                        ]
                        (el [ centerX ] (text "Login to Scheduler"))
                    , column
                        [ spacing 15
                        ]
                        [ Input.username
                            [ Input.focusedOnLoad
                            , alignRight
                            , width (px 300)
                            , padding 15
                            , spacing 15
                            ]
                            { label = Input.labelLeft [] (text "Email")
                            , onChange = UpdateEmail
                            , placeholder = Just (Input.placeholder [] (text "you@something.com"))
                            , text = page.loginInfo.email
                            }
                        , Input.currentPassword
                            [ alignRight
                            , width (px 300)
                            , padding 15
                            , spacing 15
                            ]
                            { onChange = UpdatePassword
                            , text = page.loginInfo.password
                            , label = Input.labelLeft [] (text "Password")
                            , placeholder = Just (Input.placeholder [] (text "Password"))
                            , show = False
                            }
                        ]
                    , row
                        [ alignRight
                        , width (px 300)
                        , paddingXY 0 15
                        ]
                        [ Input.button
                            [ alignLeft
                            , BG.color (rgb 0.25 0.8 0.25)
                            , defaultShadow
                            , padding 10
                            ]
                            { label = text "Login"
                            , onPress = Just LoginRequest
                            }
                        ]
                    ]
                ]

        _ ->
            text "Error: viewing login while on another page"


foldDaysLeftInYear : YearMonthDay -> Int -> Int
foldDaysLeftInYear ymd soFar =
    let
        thisMonth =
            daysLeftInMonth ymd

        newTotal =
            soFar + thisMonth
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
daysLeftInMonth ymd =
    (daysInMonth (ymFromYmd ymd) + 1) - ymd.day


foldAddDaysBetween : YearMonthDay -> YearMonthDay -> Int -> Int
foldAddDaysBetween day1 day2 soFar =
    if day1.year < day2.year then
        foldAddDaysBetween
            (YearMonthDay (day1.year + 1) 1 1)
            day2
            (foldDaysLeftInYear day1 0 + soFar)

    else if day1.month < day2.month then
        foldAddDaysBetween
            (YearMonthDay day1.year (day1.month + 1) 1)
            day2
            (daysLeftInMonth day1 + soFar)

    else if day1.day < day2.day then
        soFar + (day2.day - day1.day)

    else
        soFar


daysApart : YearMonthDay -> YearMonthDay -> Maybe Int
daysApart day1 day2 =
    case getDayState (Just day1) (Just day2) of
        Past ->
            Just (foldAddDaysBetween day1 day2 0)

        Today ->
            Just 0

        Future ->
            Just (foldAddDaysBetween day2 day1 0)

        _ ->
            Nothing


dayRepeatMatch startDay matchDay everyX =
    case daysApart startDay matchDay of
        Just apart ->
            if modBy everyX apart == 0 then
                True

            else
                False

        Nothing ->
            False


weekRepeatMatch startDay matchDay everyX =
    dayRepeatMatch startDay matchDay (everyX * 7)


shiftMatch : YearMonthDay -> Shift -> Bool
shiftMatch ymd shift =
    let
        shiftYMD =
            YearMonthDay shift.year shift.month shift.day
    in
    case ( shift.repeat, shift.everyX ) of
        ( EveryWeek, Just everyX ) ->
            weekRepeatMatch shiftYMD ymd everyX

        ( EveryDay, Just everyX ) ->
            dayRepeatMatch shiftYMD ymd everyX

        _ ->
            case dayCompare ymd shiftYMD of
                EQ ->
                    True

                _ ->
                    False


convertYMIntToYMD : Int -> Int -> Int -> YearMonthDay
convertYMIntToYMD year month dayUnbounded =
    let
        monthDays =
            daysInMonth <| YearMonth year month
    in
    if dayUnbounded > monthDays then
        case month of
            12 ->
                convertYMIntToYMD (year + 1) 1 (dayUnbounded - monthDays)

            _ ->
                convertYMIntToYMD year (month + 1) (dayUnbounded - monthDays)

    else if dayUnbounded < 1 then
        case month of
            1 ->
                let
                    priorYear =
                        year - 1

                    priorMonth =
                        12

                    priorMonthDays =
                        daysInMonth <| YearMonth priorYear priorMonth
                in
                convertYMIntToYMD priorYear priorMonth (dayUnbounded + priorMonthDays)

            _ ->
                let
                    priorMonth =
                        month - 1

                    priorMonthDays =
                        daysInMonth <| YearMonth year priorMonth
                in
                convertYMIntToYMD year priorMonth (dayUnbounded + priorMonthDays)

    else
        YearMonthDay year month dayUnbounded


addDaysToDate : YearMonthDay -> Int -> YearMonthDay
addDaysToDate ymd days =
    convertYMIntToYMD
        ymd.year
        ymd.month
        (ymd.day + days)


ymdListFromVacation : Vacation -> List YearMonthDay
ymdListFromVacation vacation =
    let
        durationDays =
            Maybe.withDefault 1 vacation.durationDays

        dayRange =
            List.range
                vacation.startDay
                (vacation.startDay + durationDays - 1)
    in
    List.map
        (\dayUnbounded ->
            convertYMIntToYMD
                vacation.startYear
                vacation.startMonth
                dayUnbounded
        )
        dayRange


vacationContainsYMD : Vacation -> YearMonthDay -> Bool
vacationContainsYMD vacation ymd =
    let
        ymdRange =
            ymdListFromVacation vacation

        filtered =
            List.filter
                (\vacYMD ->
                    case dayCompare vacYMD ymd of
                        EQ ->
                            True

                        _ ->
                            False
                )
                ymdRange
    in
    case filtered of
        [] ->
            False

        _ ->
            True


vacationStartDate : Vacation -> YearMonthDay
vacationStartDate vacation =
    YearMonthDay
        vacation.startYear
        vacation.startMonth
        vacation.startDay


shiftDate : Shift -> YearMonthDay
shiftDate shift =
    YearMonthDay
        shift.year
        shift.month
        shift.day


shiftCompare : Shift -> Shift -> Order
shiftCompare s1 s2 =
    case dayCompare (shiftDate s1) (shiftDate s2) of
        LT ->
            LT

        EQ ->
            shiftHourCompare s1 s2

        GT ->
            GT


shiftHourCompare : Shift -> Shift -> Order
shiftHourCompare s1 s2 =
    case compare s1.hour s2.hour of
        LT ->
            LT

        EQ ->
            compare s1.minute s2.minute

        GT ->
            GT


filterShiftsByDate :
    YearMonthDay
    -> List Shift
    -> List Shift
filterShiftsByDate day shifts =
    List.filter (shiftMatch day) shifts
        |> List.map (\s -> { s | year = day.year, month = day.month, day = day.day })
        |> List.sortWith shiftHourCompare


filterVacationsByDate :
    YearMonthDay
    -> List Vacation
    -> List Vacation
filterVacationsByDate day vacations =
    List.filter (\v -> vacationContainsYMD v day) vacations
        |> List.sortWith
            (\v1 v2 ->
                let
                    d1 =
                        vacationStartDate v1

                    d2 =
                        vacationStartDate v2
                in
                dayCompare d1 d2
            )


endsFromStartDur : Float -> Float -> ( Float, Float )
endsFromStartDur start duration =
    let
        end =
            start + duration
    in
    ( start, end )


formatHour12 : Bool -> Float -> String
formatHour12 showMinutes floatTime =
    let
        rawHour =
            floor floatTime

        hour24 =
            modBy 24 rawHour

        hour12 =
            modBy 12 rawHour

        minutes =
            case showMinutes of
                True ->
                    ":" ++ floatToMinuteString floatTime

                False ->
                    ""
    in
    if hour24 > 12 then
        String.fromInt hour12 ++ minutes ++ "p"

    else if hour24 == 12 then
        String.fromInt 12 ++ minutes ++ "p"

    else
        String.fromInt hour12 ++ minutes ++ "a"


formatHour24 : Bool -> Float -> String
formatHour24 showMinutes floatTime =
    let
        rawHour =
            floor floatTime

        hour24 =
            modBy 24 rawHour

        minutes =
            case showMinutes of
                True ->
                    ":" ++ floatToMinuteString floatTime

                False ->
                    ""
    in
    String.fromInt hour24 ++ minutes


formatHours : Settings -> Float -> Float -> Maybe String -> Element Message
formatHours settings start duration maybeNote =
    let
        noteFormatted =
            case maybeNote of
                Just note ->
                    case note of
                        "" -> note
                        _ ->
                            " ("
                                ++ note
                                ++ ")"

                Nothing ->
                    ""
    in
    case settings.hourFormat of
        Hour12 ->
            let
                ( _, end ) =
                    endsFromStartDur start duration
            in
            text
                (formatHour12 settings.showMinutes start
                    ++ "-"
                    ++ formatHour12 settings.showMinutes end
                    ++ noteFormatted
                )

        Hour24 ->
            let
                ( _, end ) =
                    endsFromStartDur start duration
            in
            text
                (formatHour24 settings.showMinutes start
                    ++ "-"
                    ++ formatHour24 settings.showMinutes end
                    ++ noteFormatted
                )


type alias Week =
    Array (Maybe YearMonthDay)


rowDefault : Week
rowDefault =
    Array.repeat 7 Nothing


type alias Month =
    Array Week


type alias RowID =
    { index : Int
    , maybeRow : Maybe Week
    }


type alias DayID =
    { index : Int
    , maybeDay : Maybe YearMonthDay
    }


monthDefault : Month
monthDefault =
    Array.repeat 6 rowDefault


makeDaysForMonth : YearMonth -> Array YearMonthDay
makeDaysForMonth ym =
    List.range 1 (daysInMonth ym)
        |> List.map (\d -> withDay ym d)
        |> Array.fromList


foldAllEmpty : Maybe YearMonthDay -> Bool -> Bool
foldAllEmpty maybeYMD emptySoFar =
    case emptySoFar of
        True ->
            case maybeYMD of
                Just _ ->
                    False

                Nothing ->
                    True

        False ->
            False


allEmpty : Array (Maybe YearMonthDay) -> Bool
allEmpty ymdArray =
    Array.foldl foldAllEmpty True ymdArray


foldRowSelect : Int -> Week -> ( RowID, DayID ) -> ( RowID, DayID )
foldRowSelect targetIndex row ( rowID, dayID ) =
    case allEmpty (Array.slice targetIndex 7 row) of
        True ->
            case rowID.maybeRow of
                Just alreadyFound ->
                    ( rowID, dayID )

                Nothing ->
                    ( RowID rowID.index (Just row), DayID targetIndex Nothing )

        False ->
            ( RowID (rowID.index + 1) Nothing, dayID )


defaultID =
    ( RowID 0 Nothing, DayID 0 Nothing )


selectPositionForDay : YearMonthDay -> Month -> ( RowID, DayID )
selectPositionForDay ymd month =
    let
        dayIndex =
            toWeekday ymd - 1
    in
    Array.foldl (foldRowSelect dayIndex) defaultID month


foldPlaceDay : YearMonthDay -> Month -> Month
foldPlaceDay ymd inMonth =
    let
        ( rowID, dayID ) =
            selectPositionForDay
                ymd
                inMonth

        newRow =
            case rowID.maybeRow of
                Just row ->
                    Array.set
                        dayID.index
                        (Just ymd)
                        row

                Nothing ->
                    rowDefault
    in
    Array.set rowID.index newRow inMonth


placeDays : Array YearMonthDay -> Month -> Month
placeDays ymd month =
    Array.foldl foldPlaceDay month ymd


makeGridFromMonth : YearMonth -> Month
makeGridFromMonth ym =
    let
        days =
            makeDaysForMonth ym
    in
    placeDays days monthDefault


type YMDFormat
    = ShortDate
    | LongDate


type alias YMDStringSettings =
    { format : YMDFormat
    , includeWeekday : Bool
    }


ymdToString : YearMonthDay -> Maybe YMDStringSettings -> String
ymdToString ymd maybeSettings =
    let
        settings =
            case maybeSettings of
                Just includedSettings ->
                    includedSettings

                Nothing ->
                    YMDStringSettings LongDate True

        yearStr =
            String.fromInt ymd.year

        monthStr =
            monthNumToString ymd.month

        monthNumStr =
            String.fromInt ymd.month

        dayStr =
            String.fromInt ymd.day

        weekdayStr =
            weekdayNumToString (toWeekday ymd)

        p1 =
            case settings.includeWeekday of
                True ->
                    weekdayStr ++ " "

                False ->
                    ""

        p2 =
            case settings.format of
                LongDate ->
                    monthStr
                        ++ " "
                        ++ dayStr
                        ++ ", "
                        ++ yearStr

                ShortDate ->
                    monthNumStr
                        ++ "/"
                        ++ dayStr
                        ++ "/"
                        ++ yearStr
    in
    -- Weekday, Month Day, Year
    p1
        ++ p2


getEmployee : List Employee -> Maybe Int -> Maybe Employee
getEmployee employees maybeID =
    case maybeID of
        Just id ->
            List.filter (\emp -> emp.id == id) employees
                |> List.head

        Nothing ->
            Nothing


getViewEmployees : List Employee -> List Int -> List Employee
getViewEmployees employees viewEmployees =
    List.filterMap
        (\id -> getEmployee employees (Just id))
        viewEmployees


formatLastName : LastNameStyle -> String -> String
formatLastName lastNameStyle name =
    case lastNameStyle of
        FullName ->
            name

        FirstInitial ->
            String.left 1 name

        Hidden ->
            ""


vacationElement :
    Model
    -> List Employee
    -> CombinedSettings
    -> YearMonthDay
    -> Vacation
    -> Element Message
vacationElement model viewEmployees combined day vacation =
    let
        matchEmployees =
            List.filter (\e -> e.id == vacation.employeeID) viewEmployees

        settings =
            combined.settings

        perEmployee =
            getEmployeeSettings model (Just vacation.employeeID)
    in
    case matchEmployees of
        [ employee ] ->
            Input.button
                [ Font.size 18
                , paddingXY 0 2
                , Border.width 2
                , Border.rounded 3
                , BG.color white
                , case vacation.approved of
                    True ->
                        Border.solid

                    False ->
                        Border.dashed
                , fillX
                ]
                { onPress =
                    Just <|
                        OpenVacationModal <|
                            VacationData
                                False
                                vacation
                                day
                , label =
                    el [ centerX ] <|
                        text <|
                            nameToString
                                employee.name
                                settings.lastNameStyle
                                ++ " off"
                }

        _ ->
            none


filterVacationsForShift : Model -> Shift -> List Vacation
filterVacationsForShift model shift =
    let
        vacations =
            Maybe.withDefault [] model.vacations

        day =
            shiftDate shift

        matchedVacations =
            List.filter
                (\v ->
                    case shift.employeeID of
                        Just employeeID ->
                            vacationContainsYMD v day
                                && v.employeeID
                                == employeeID
                                && v.approved
                                == True

                        Nothing ->
                            False
                )
                vacations
    in
    matchedVacations

getEmployeeColor : Model -> Maybe Int -> EmployeeColor
getEmployeeColor model maybeID =
    case getEmployeeSettings model maybeID of
        Just perEmployee -> perEmployee.color
        Nothing -> 
            let
                employees = Maybe.withDefault [] model.employees
                maybeEmployee = getEmployee employees maybeID
                defaultColor = case maybeEmployee of
                    Just employee ->
                        employee.defaultColor
                    Nothing -> Green
                
            in
                defaultColor

shiftColorStyle : Model -> Shift -> List (Attribute Message)
shiftColorStyle model shift =
    let
        colorPair =
            employeeColor <| getEmployeeColor model shift.employeeID
    in
    [ Border.color <| fromRgb colorPair.dark
    , BG.color <| fromRgb colorPair.light
    ]

shiftQuarterHours : Float -> Int
shiftQuarterHours f =
    (floatToQuarterHour f // 15)
        + (floatToHour f * 4)


preShiftSpace : Shift -> YearMonthDay -> Int
preShiftSpace shift viewDate =
    let
        f =
            hourMinuteToFloat shift.hour shift.minute
    in
    case dayCompare (shiftDate shift) viewDate of
        LT ->
            0

        EQ ->
            shiftQuarterHours f

        GT ->
            24 * 4


shiftSpace : Shift -> YearMonthDay -> Int
shiftSpace shift viewDate =
    let
        startF =
            hourMinuteToFloat shift.hour shift.minute

        durF =
            hourMinuteToFloat shift.hours shift.minutes

        endF =
            startF + durF
    in
    case dayCompare (shiftDate shift) viewDate of
        LT ->
            case compare endF 24 of
                LT ->
                    0

                _ ->
                    shiftQuarterHours (endF - 24)

        EQ ->
            case compare endF 24 of
                LT ->
                    shiftQuarterHours durF

                _ ->
                    shiftQuarterHours (durF - (endF - 24))

        GT ->
            0


postShiftSpace : Shift -> YearMonthDay -> Int
postShiftSpace shift viewDate =
    let
        pre =
            preShiftSpace shift viewDate

        dur =
            shiftSpace shift viewDate
    in
    (24 * 4) - (pre + dur)


shiftHoursElement :
    Model
    -> List Employee
    -> CombinedSettings
    -> YearMonthDay
    -> Shift
    -> Element Message
shiftHoursElement model viewEmployees combined viewDate shift =
    let
        settings =
            combined.settings

        matchedVacations =
            filterVacationsForShift model shift

        startFloat =
            hourMinuteToFloat shift.hour shift.minute

        durationFloat =
            hourMinuteToFloat shift.hours shift.minutes

        startQuarters =
            preShiftSpace shift viewDate

        durationQuarters =
            shiftSpace shift viewDate

        endQuarters =
            postShiftSpace shift viewDate
    in
    case ( getEmployee viewEmployees shift.employeeID, matchedVacations, durationQuarters ) of
        ( _, _, 0 ) ->
            none

        ( Just employee, [], _ ) ->
            row
                [ fillX
                , Font.size 18
                ]
                [ el [ width <| fillPortion startQuarters ] none
                , Input.button
                    ([ width <| fillPortion durationQuarters ] ++ defaultBorder ++ shiftColorStyle model shift)
                    { onPress =
                        Just <|
                            OpenShiftModal <|
                                ShiftData
                                    False
                                    shift
                                    (Just employee)
                                    ""
                                    viewEmployees
                                    viewDate
                                    (Maybe.withDefault "" shift.note)
                    , label =
                        el
                            [ centerX
                            , height <| minimum 40 fill
                            , inFront <|
                                column
                                [ centerX, centerY ]
                                [ row
                                    []
                                    [ text
                                        (nameToString employee.name settings.lastNameStyle
                                            ++ ": "
                                        )
                                    , formatHours settings startFloat durationFloat shift.note
                                    ]
                                , case (shift.onCall, employee.phoneNumber) of
                                        (True, Just phoneNumber) -> 
                                            case phoneNumber of
                                                "" -> none
                                                _ -> el [] <| text <| phoneNumber
                                        _ -> none
                                ]
                            ]
                            none
                    }
                , el [ width <| fillPortion endQuarters ] none
                ]

        _ ->
            none


shiftElement :
    Model
    -> List Employee
    -> CombinedSettings
    -> YearMonthDay
    -> Shift
    -> Element Message
shiftElement model viewEmployees combined day shift =
    let
        settings =
            combined.settings

        matchedVacations =
            filterVacationsForShift model shift

        floatBegin =
            hourMinuteToFloat shift.hour shift.minute

        floatDuration =
            hourMinuteToFloat shift.hours shift.minutes
    in
    case ( getEmployee viewEmployees shift.employeeID, matchedVacations ) of
        ( Just employee, [] ) ->
            Input.button
                [ fillX
                , clipX
                ]
                { onPress =
                    Just <|
                        OpenShiftModal <|
                            ShiftData
                                False
                                shift
                                (Just employee)
                                ""
                                viewEmployees
                                day
                                (Maybe.withDefault "" shift.note)
                , label =
                    column
                        ([ Font.size 18
                        , paddingXY 0 2
                        , Border.width 2
                        , Border.rounded 3
                        , fillX
                        ]
                            ++ shiftColorStyle model shift
                        )
                        [ row
                          []
                            [ el [ padding 1 ] <|
                                text
                                    (nameToString employee.name settings.lastNameStyle
                                        ++ ": "
                                    )
                            
                            , formatHours settings floatBegin floatDuration shift.note
                            ]
                        , case (shift.onCall, employee.phoneNumber) of
                            (True, Just phoneNumber) -> 
                                case phoneNumber of
                                    "" -> none
                                    _ -> el [] <| text <| phoneNumber
                            _ -> none
                        ]
                }

        _ ->
            none


dayStyle : DayState -> List (Attribute Message)
dayStyle dayState =
    [ width fill
    , height fill
    , clipX
    , clipY
    , scrollbarX
    , Border.widthEach { bottom = 0, left = 1, right = 0, top = 0 }
    , Border.color (rgb 0.2 0.2 0.2)
    ]
        ++ (case dayState of
                Today ->
                    [ BG.color (rgb 0.99 1 0.99)
                    , Border.innerGlow lightGreen 3
                    ]

                Future ->
                    []

                Past ->
                    [ -- Border.innerGlow grey 3,
                      BG.color lightGrey
                    ]

                None ->
                    []
           )


shiftHoursColumn :
    Model
    -> List Employee
    -> CombinedSettings
    -> YearMonthDay
    -> Element Message
shiftHoursColumn model viewEmployees combined viewDate =
    let
        shifts =
            Maybe.withDefault [] model.shifts
            |> List.filter (\s -> s.onCall == False)

        priorDate =
            addDaysToDate viewDate -1

        viewDateShifts =
            filterShiftsByDate viewDate shifts

        priorDayShifts =
            filterShiftsByDate priorDate shifts

        viewShifts =
            priorDayShifts ++ viewDateShifts
    in
    column
        [ fillX
        ]
        (List.map
            (shiftHoursElement model viewEmployees combined viewDate)
            viewShifts
        )

callShiftHoursColumn :
    Model
    -> List Employee
    -> CombinedSettings
    -> YearMonthDay
    -> Element Message
callShiftHoursColumn model viewEmployees combined viewDate =
    let
        shifts =
            Maybe.withDefault [] model.shifts
            |> List.filter (\s -> s.onCall == True)

        priorDate =
            addDaysToDate viewDate -1

        viewDateShifts =
            filterShiftsByDate viewDate shifts

        priorDayShifts =
            filterShiftsByDate priorDate shifts

        viewShifts =
            priorDayShifts ++ viewDateShifts
    in
    column
        [ fillX
        ]
        (List.map
            (shiftHoursElement model viewEmployees combined viewDate)
            viewShifts
        )


shiftColumn :
    Model
    -> List Employee
    -> CombinedSettings
    -> YearMonthDay
    -> Element Message
shiftColumn model viewEmployees combined day =
    let
        shifts =
            Maybe.withDefault [] model.shifts
            |> List.filter (\s -> s.onCall == False)
    in
    column
        [ fillX
        ]
        (List.map
            (shiftElement model viewEmployees combined day)
            (filterShiftsByDate day shifts)
        )

callShiftColumn :
    Model
    -> List Employee
    -> CombinedSettings
    -> YearMonthDay
    -> Element Message
callShiftColumn model viewEmployees combined day =
    let
        shifts =
            Maybe.withDefault [] model.shifts
            |> List.filter (\s -> s.onCall == True)
    in
    column
        [ fillX
        ]
        (List.map
            (shiftElement model viewEmployees combined day)
            (filterShiftsByDate day shifts)
        )


vacationColumn :
    Model
    -> List Employee
    -> CombinedSettings
    -> YearMonthDay
    -> Element Message
vacationColumn model viewEmployees combined day =
    let
        vacations =
            Maybe.withDefault [] model.vacations
    in
    column
        [ fillX
        , alignBottom
        ]
        (List.map
            (vacationElement model viewEmployees combined day)
            (filterVacationsByDate day vacations)
        )


type ShiftRepeat
    = NeverRepeat
    | EveryWeek
    | EveryDay


updateShift : Shift -> Cmd Message
updateShift shift =
    Http.post
        { url = "/sched/update_shift"
        , body = Http.jsonBody (shiftEncoder shift)
        , expect = Http.expectWhatever ReloadData
        }


updateVacation : Vacation -> Cmd Message
updateVacation vacation =
    Http.post
        { url = "/sched/update_vacation"
        , body = Http.jsonBody <| vacationEncoder vacation
        , expect = Http.expectWhatever ReloadData
        }


updateVacationApproval : Vacation -> Cmd Message
updateVacationApproval vacation =
    Http.post
        { url = "/sched/update_vacation_approval"
        , body = Http.jsonBody <| vacationEncoder vacation
        , expect = Http.expectWhatever ReloadData
        }


type alias ShiftData =
    { editEnabled : Bool
    , shift : Shift
    , employee : Maybe Employee
    , employeeSearch : String
    , employeeMatches : List Employee
    , date : YearMonthDay
    , note : String
    }


type alias VacationData =
    { editEnabled : Bool
    , vacation : Vacation
    , date : YearMonthDay
    }


type alias ViewSelectData =
    {}


type alias ViewEditData =
    { settings : Settings
    , changed : Bool
    , colorSelect : Maybe Employee
    }


defaultViewEdit : Settings -> ViewEditData
defaultViewEdit settings =
    ViewEditData settings False Nothing


chooseSuffix : Float -> String
chooseSuffix f =
    let
        h24 =
            modBy 24 (floor f)
    in
    if h24 >= 12 then
        "PM"

    else
        "AM"


floatToQuarterHour : Float -> Int
floatToQuarterHour f =
    let
        fractional =
            f - toFloat (truncate f)

        minutes =
            fractional * 60
    in
    round (minutes / 15) * 15


floatToMinuteString : Float -> String
floatToMinuteString f =
    let
        nearestQuarter =
            floatToQuarterHour f
    in
    case nearestQuarter of
        0 ->
            "00"

        _ ->
            String.fromInt nearestQuarter


floatToHour : Float -> Int
floatToHour f =
    modBy 24 (floor f)


floatToTimeString : Float -> HourFormat -> String
floatToTimeString f hourFormat =
    case hourFormat of
        Hour12 ->
            let
                suffix =
                    chooseSuffix f

                hour =
                    floor f |> modBy 12

                hourFixed =
                    if hour == 0 then
                        12

                    else
                        hour

                hourStr =
                    if hourFixed < 10 then
                        "0" ++ String.fromInt hourFixed

                    else
                        String.fromInt hourFixed

                minutesStr =
                    floatToMinuteString f
            in
            hourStr ++ ":" ++ minutesStr ++ suffix

        Hour24 ->
            let
                hour =
                    floatToHour f

                hourStr =
                    if hour < 10 then
                        "0" ++ String.fromInt hour

                    else
                        String.fromInt hour

                minutesStr =
                    floatToMinuteString f
            in
            hourStr ++ ":" ++ minutesStr


floatToDurationString : Float -> String
floatToDurationString f =
    let
        hours =
            floor f

        hoursStr =
            if hours < 10 then
                "0" ++ String.fromInt hours

            else
                String.fromInt hours

        minutesStr =
            floatToMinuteString f
    in
    hoursStr ++ ":" ++ minutesStr


employeeAutofillElement : List Employee -> List (Input.Option Employee Message)
employeeAutofillElement employeeList =
    List.map
        (\employee ->
            Input.optionWith
                employee
            <|
                \state ->
                    el
                        (List.append
                            [ padding 5
                            , defaultShadow
                            ]
                            (case state of
                                Input.Selected ->
                                    [ BG.color white
                                    , Border.color black
                                    , Border.width 1
                                    ]

                                _ ->
                                    [ BG.color modalColor
                                    , Border.color borderColor
                                    ]
                            )
                        )
                        (text (nameToString employee.name FullName))
        )
        employeeList


modalColor =
    rgb 0.9 0.9 0.9


defaultShadow =
    Border.shadow
        { offset = ( 3, 3 )
        , size = 3
        , blur = 6
        , color = rgba 0 0 0 0.25
        }


black =
    rgb 0 0 0


grey =
    rgb 0.5 0.5 0.5


white =
    rgb 1 1 1


lightGreen =
    rgb 0.65 0.85 0.65


lightGrey =
    rgb 0.85 0.85 0.85


borderColor =
    rgb 0.7 0.7 0.7


defaultBorder =
    [ Border.solid
    , Border.color borderColor
    , Border.width 1
    , Border.rounded 3
    ]


headerFontSize =
    Font.size 30


shiftWriteAccess : Employee -> Shift -> Bool
shiftWriteAccess currentEmployee shift =
    case currentEmployee.level of
        Read ->
            False

        _ ->
            if currentEmployee.id == shift.supervisorID then
                True

            else
                False


vacationWriteAccess : Employee -> Vacation -> Bool
vacationWriteAccess currentEmployee vacation =
    if currentEmployee.id == vacation.employeeID then
        True

    else
        False


shiftEditElement shift editData settings =
    column
        [ centerX
        , centerY
        , BG.color modalColor
        , padding 15
        , defaultShadow
        , spacing 10
        ]
        [ -- Navigation buttons
          row
            ([ padding 5
             , fillX
             ]
                ++ defaultBorder
            )
            [ Input.button
                [ BG.color red
                , padding 5
                , defaultShadow
                , centerX
                , Font.color white
                ]
                { onPress = Just <| RemoveEventAndClose <| ShiftEvent shift
                , label = text "Delete Shift"
                }
            ]
        , -- Employee search/select
          column
            [ spacing 15
            , paddingXY 0 15
            ]
            [ Input.search
                [ fillX
                , defaultShadow
                , centerX
                , htmlAttribute (HtmlAttr.id "employeeSearch")
                , onRight
                    (case editData.employee of
                        Just employee ->
                            el
                                [ fillX, fillY, paddingXY 10 0 ]
                                (el
                                    [ alignBottom
                                    , BG.color white
                                    , Border.color lightGreen
                                    , Border.width 2
                                    , Border.rounded 3
                                    , padding 12
                                    ]
                                 <|
                                    text <|
                                        nameToString employee.name FullName
                                )

                        Nothing ->
                            el [ fillX ] none
                    )
                ]
                { onChange = ShiftEmployeeSearch
                , text = editData.employeeSearch
                , placeholder = Nothing
                , label = Input.labelAbove [ centerX, padding 2 ] (text "Find employee: ")
                }
            , Input.radio
                ([ clipY
                 , scrollbarY
                 , height (px 150)
                 , fillX
                 ]
                    ++ defaultBorder
                )
                { onChange = ChooseShiftEmployee
                , selected = editData.employee
                , label = Input.labelHidden "Employees"
                , options =
                    employeeAutofillElement
                        editData.employeeMatches
                }
            ]
        , -- Shift note
          el [ fillX ] <|
            Input.text
                [ centerX
                , Events.onLoseFocus ShiftEditUnfocusNote
                ]
                { onChange = ShiftEditUpdateNote
                , text = editData.note
                , placeholder =
                    Just
                        (Input.placeholder [] (text "Note"))
                , label = Input.labelHidden "Note"
                }
        , -- Shift start slider
          column
            ([ fillX
             ]
                ++ defaultBorder
            )
            [ row
                []
                [ text "Start at: "
                , el
                    [ BG.color white
                    , Border.solid
                    , Border.color borderColor
                    , Border.width 1
                    , Border.rounded 3
                    , padding 3
                    , Font.family
                        [ Font.monospace
                        ]
                    ]
                    (text
                        (floatToTimeString
                            (hourMinuteToFloat shift.hour shift.minute)
                            settings.hourFormat
                        )
                    )
                ]
            , Input.slider
                [ -- Slider BG
                  behindContent
                    (el
                        [ BG.color white
                        , centerY
                        , fillX
                        , height (px 5)
                        ]
                        none
                    )
                ]
                { onChange = UpdateShiftStart
                , label =
                    Input.labelHidden "Start Time"
                , min = 0
                , max = 23.75
                , value = hourMinuteToFloat shift.hour shift.minute
                , step = Just 0.25
                , thumb = Input.defaultThumb
                }
            ]
        , -- Shift duration slider
          column
            ([ fillX
             ]
                ++ defaultBorder
            )
            [ -- Label for duration slider
              row
                [ fillX
                ]
                [ text "Duration: "
                , el
                    ([ BG.color white
                     , padding 3
                     , Font.family
                        [ Font.monospace
                        ]
                     ]
                        ++ defaultBorder
                    )
                    (text
                        (floatToDurationString
                            (hourMinuteToFloat shift.hours shift.minutes)
                        )
                    )
                , text " Ends: "
                , el
                    ([ BG.color white
                     , padding 3
                     , Font.family
                        [ Font.monospace
                        ]
                     ]
                        ++ defaultBorder
                    )
                    (text
                        (floatToTimeString
                            (hourMinuteToFloat shift.hour shift.minute
                                + hourMinuteToFloat shift.hours shift.minutes
                            )
                            settings.hourFormat
                        )
                    )
                ]
            , Input.slider
                [ -- Slider BG
                  behindContent
                    (el
                        [ BG.color white
                        , centerY
                        , fillX
                        , height (px 5)
                        ]
                        none
                    )
                ]
                { onChange = UpdateShiftDuration
                , label =
                    Input.labelHidden "Shift Duration"
                , min = 0
                , max = 16
                , value = hourMinuteToFloat shift.hours shift.minutes
                , step = Just 0.25
                , thumb = Input.defaultThumb
                }
            ]
        , -- Repeat controls
          row
            []
            [ row
                ([ width shrink
                , spacing 5
                ]
                    ++ defaultBorder
                )
                [ Input.radio
                    [ BG.color white
                    , padding 5
                    ]
                    { onChange = UpdateShiftRepeat
                    , selected = Just shift.repeat
                    , label =
                        Input.labelAbove
                            [ BG.color lightGrey, fillX, padding 5 ]
                            (el [ centerX ] (text "Repeat:"))
                    , options =
                        [ Input.option NeverRepeat (text "Never")
                        , Input.option EveryWeek (text "Weekly")
                        , Input.option EveryDay (text "Daily")
                        ]
                    }
                , Input.text
                    [ width (px 50)
                    , padding 5
                    , alignTop
                    ]
                    { onChange = UpdateShiftRepeatRate
                    , text =
                        case shift.everyX of
                            Just everyX ->
                                String.fromInt everyX

                            Nothing ->
                                ""
                    , placeholder = Nothing
                    , label =
                        Input.labelAbove
                            [ BG.color lightGrey
                            , padding 5
                            ]
                            (text "Every:")
                    }
                ]
            , Input.checkbox
                ([ BG.color white
                , padding 10] ++ defaultBorder)
                { onChange = UpdateShiftOnCall
                , checked = shift.onCall
                , label =
                    Input.labelRight
                        [ BG.color lightGrey, fillX, padding 5 ]
                        (el [ centerX ] (text "On call"))
                , icon = Input.defaultCheckbox
                }
            ]
        ]


tabSelectElement element state =
    case state of
        Input.Selected ->
            el
                [ BG.color white
                , Border.color black
                , Border.widthEach
                    { top = 2
                    , left = 2
                    , right = 2
                    , bottom = 0
                    }
                , Border.shadow
                    { offset = ( 0, -3 )
                    , size = 3
                    , blur = 6
                    , color = rgba 0 0 0 0.25
                    }
                , Border.roundEach
                    { topLeft = 3
                    , topRight = 3
                    , bottomLeft = 0
                    , bottomRight = 0
                    }
                , Border.solid
                , paddingEach
                    { top = 0
                    , left = 5
                    , right = 5
                    , bottom = 0
                    }
                , alignBottom
                ]
                element

        _ ->
            el
                [ BG.color modalColor
                , Border.color black
                , Border.widthEach
                    { top = 1
                    , left = 1
                    , right = 1
                    , bottom = 0
                    }
                , Border.roundEach
                    { topLeft = 3
                    , topRight = 3
                    , bottomLeft = 0
                    , bottomRight = 0
                    }
                , Border.solid
                , paddingEach
                    { top = 0
                    , left = 5
                    , right = 5
                    , bottom = 0
                    }
                , alignBottom
                ]
                element


employeeNameElement employee =
    el
        [ fillX, fillY, paddingXY 10 0 ]
        (el
            [ centerX
            , BG.color white
            , Border.color lightGreen
            , Border.width 2
            , Border.rounded 3
            , padding 12
            ]
         <|
            text <|
                nameToString employee.name FullName
        )


shiftTimesElement : Shift -> Settings -> Element Message
shiftTimesElement shift settings =
    let
        floatStart =
            hourMinuteToFloat
                shift.hour
                shift.minute

        floatDuration =
            hourMinuteToFloat
                shift.hours
                shift.minutes

        floatEnd =
            floatStart + floatDuration

        startString =
            case settings.hourFormat of
                Hour12 ->
                    formatHour12
                        True
                        floatStart

                Hour24 ->
                    formatHour24
                        True
                        floatStart

        endString =
            case settings.hourFormat of
                Hour12 ->
                    formatHour12
                        True
                        floatEnd

                Hour24 ->
                    formatHour24
                        True
                        floatEnd

        durationString =
            floatToDurationString
                floatDuration
    in
    column
        ([ fillX, padding 10 ] ++ defaultBorder)
        [ row [ fillX ]
            [ el [ alignRight ] <| text "Starts at "
            , el [ padding 5, BG.color white, alignRight ] <|
                text startString
            ]
        , row [ fillX ]
            [ el [ alignRight ] <| text "Lasts "
            , el [ padding 5, BG.color white, alignRight ] <|
                text durationString
            ]
        , row [ fillX ]
            [ el [ alignRight ] <| text "Ends at "
            , el [ padding 5, BG.color white, alignRight ] <|
                text endString
            ]
        ]


shiftRepeatElement shift =
    el ([ padding 10, centerX ] ++ defaultBorder) <|
        case ( shift.repeat, shift.everyX ) of
            ( EveryWeek, Just everyX ) ->
                text <|
                    "Shift repeats every "
                        ++ (case everyX of
                                1 ->
                                    "week."

                                _ ->
                                    String.fromInt everyX
                                        ++ " weeks."
                           )

            ( EveryDay, Just everyX ) ->
                text <|
                    "Shift repeats every "
                        ++ (case everyX of
                                1 ->
                                    "day."

                                _ ->
                                    String.fromInt everyX
                                        ++ " days."
                           )

            _ ->
                text "Shift does not repeat."


shiftViewElement : Shift -> ShiftData -> Settings -> Element Message
shiftViewElement shift editData settings =
    let
        dateFormat =
            Just <| YMDStringSettings LongDate True
    in
    column
        [ centerX
        , centerY
        , BG.color modalColor
        , padding 15
        , defaultShadow
        , spacingXY 0 15
        ]
        [ -- Selected Day display
          el
            ([ padding 5
             , centerX
             ]
                ++ defaultBorder
            )
          <|
            text <|
                ymdToString editData.date dateFormat

        -- Employee display
        , case editData.employee of
            Just employee ->
                employeeNameElement employee

            Nothing ->
                el
                    [ padding 5
                    , Border.color red
                    , Border.width 1
                    , Border.rounded 3
                    ]
                <|
                    text "No employee selected"
        , -- On Call Status
          case (shift.onCall, editData.employee) of
            (True, Just employee) -> 
                let 
                    phoneNumber = case employee.phoneNumber of
                        Just pn -> case pn of
                            "" -> "No number listed"
                            _ -> pn
                        Nothing -> "No number listed"
                in
                el
                    [ fillX
                    , padding 10
                    , BG.color white
                    , Border.width 2
                    , Border.color yellow
                    , Border.rounded 3
                    ]
                    <| el [centerX] <| text ("On Call: " ++ phoneNumber)
            _ -> none
        , -- Note display
          case shift.note of
            Just note ->
                row ([ fillX, padding 10 ] ++ defaultBorder)
                    [ text "Note: "
                    , el [ alignRight, BG.color white, padding 5 ] <|
                        text note
                    ]

            Nothing ->
                el ([ fillX, padding 10 ] ++ defaultBorder) <|
                    el [centerX] <|
                    text "No note attached"
        , -- Shift time display
          shiftTimesElement shift settings
        , -- Shift repeat display
          shiftRepeatElement shift
        ]


greyHalfAlpha =
    rgba 0.5 0.5 0.5 0.5


modalOverlay msg element =
    el [ fillX, fillY, behindContent <| el [ fillX, fillY, Events.onClick msg, BG.color greyHalfAlpha ] none ]
        element


getSupervisors : List Employee -> List Employee
getSupervisors employees =
    List.filter (\e -> e.level == Supervisor) employees


vacationTimeElement : Vacation -> Settings -> Element Message
vacationTimeElement vacation settings =
    let
        dateFormat =
            Just <| YMDStringSettings LongDate True

        start =
            vacationStartDate vacation

        startString =
            "Starts "
                ++ ymdToString start dateFormat

        durationDays =
            Maybe.withDefault 1 vacation.durationDays

        durationString =
            "Lasts "
                ++ String.fromInt durationDays
                ++ (case durationDays of
                        1 ->
                            " day"

                        _ ->
                            " days"
                   )

        end =
            addDaysToDate start durationDays

        endString =
            "Ends " ++ ymdToString end dateFormat
    in
    column
        ([ padding 5
         , spacing 5
         , centerX
         ]
            ++ defaultBorder
        )
        [ el [ centerX ] <| text startString
        , el
            [ centerX
            , Border.widthEach
                { top = 1
                , bottom = 1
                , right = 0
                , left = 0
                }
            , padding 3
            ]
          <|
            text durationString
        , el [ centerX ] <| text endString
        ]


vacationViewElement : Model -> VacationData -> Vacation -> CombinedSettings -> Element Message
vacationViewElement model modalData vacation combined =
    let
        employees =
            Maybe.withDefault [] model.employees

        supervisors =
            getSupervisors employees

        maybeSupervisor =
            getEmployee supervisors vacation.supervisorID

        dateFormat =
            Just <| YMDStringSettings LongDate True
    in
    column
        [ centerX
        , centerY
        , BG.color modalColor
        , padding 15
        , defaultShadow
        , spacingXY 0 15
        ]
        [ -- Selected Day display
          el
            ([ padding 5
             , centerX
             ]
                ++ defaultBorder
            )
          <|
            text <|
                ymdToString modalData.date dateFormat
        , case maybeSupervisor of
            Just supervisor ->
                row ([ padding 5, centerX ] ++ defaultBorder) [ text "Supervisor: ", employeeNameElement supervisor ]

            Nothing ->
                el
                    [ padding 5
                    , Border.color red
                    , Border.width 1
                    , Border.rounded 3
                    ]
                <|
                    text "No supervisor selected"
        , case vacation.approved of
            True ->
                el
                    [ padding 5
                    , Border.color green
                    , Border.width 1
                    , Border.rounded 3
                    , centerX
                    ]
                <|
                    text "Approved"

            False ->
                el
                    [ padding 5
                    , Border.color red
                    , Border.width 1
                    , Border.rounded 3
                    , centerX
                    ]
                <|
                    text "Not yet approved"
        , el ([ padding 5 ] ++ defaultBorder) <|
            text <|
                "Requested "
                    ++ ymdToString (vacationRequestDate vacation) dateFormat
        , vacationTimeElement vacation combined.settings
        ]


vacationRequestDate : Vacation -> YearMonthDay
vacationRequestDate vacation =
    YearMonthDay
        vacation.requestYear
        vacation.requestMonth
        vacation.requestDay


vacationEditElement : Model -> Vacation -> VacationData -> CombinedSettings -> Element Message
vacationEditElement model vacation modalData combined =
    let
        employees =
            Maybe.withDefault [] model.employees

        maybeEmployee =
            getEmployee employees <| Just vacation.employeeID

        supervisors =
            getSupervisors employees
    in
    case maybeEmployee of
        Just employee ->
            column
                ([ fillX
                 , fillY
                 , padding 5
                 , defaultShadow
                 ]
                    ++ defaultBorder
                )
                [ el
                    ([ padding 5
                     ]
                        ++ defaultBorder
                    )
                  <|
                    text <|
                        "Vacation request for "
                            ++ nameToString employee.name FullName
                , el
                    [ fillX
                    , clipY
                    , scrollbarY
                    , height <| px 150
                    ]
                  <|
                    Input.radio
                        ([ BG.color white
                         , padding 5
                         , fillX
                         ]
                            ++ defaultBorder
                        )
                        { onChange = UpdateVacationSupervisor
                        , options =
                            List.map
                                (\e -> Input.option e <| el [ centerX ] <| text <| nameToString e.name FullName)
                                supervisors
                        , selected = getEmployee supervisors vacation.supervisorID
                        , label = Input.labelAbove [] <| text "Select supervisor:"
                        }
                , Input.text
                    []
                    { onChange = UpdateVacationDuration
                    , text =
                        case vacation.durationDays of
                            Just durationDays ->
                                String.fromInt durationDays

                            Nothing ->
                                ""
                    , placeholder = Nothing
                    , label = Input.labelLeft [] <| text "Days: "
                    }
                , row
                    ([ padding 5
                     , fillX
                     ]
                        ++ defaultBorder
                    )
                    [ Input.button
                        [ BG.color red
                        , padding 5
                        , defaultShadow
                        , centerX
                        , Font.color white
                        ]
                        { onPress = Just <| RemoveEventAndClose <| VacationEvent vacation
                        , label = text "Delete Vacation"
                        }
                    ]
                ]

        Nothing ->
            none


shiftModalElement : Model -> ShiftData -> Element Message
shiftModalElement model modalData =
    case ( getActiveSettings model, model.currentEmployee ) of
        ( Just activeSettings, Just currentEmployee ) ->
            let
                shift =
                    modalData.shift

                settings =
                    activeSettings.settings

                closeEvent =
                    case shift.employeeID of
                        Nothing ->
                            RemoveEventAndClose <|
                                ShiftEvent shift

                        _ ->
                            CloseEventModal
            in
            modalOverlay closeEvent <|
                el
                    ([ centerX
                     , centerY
                     , defaultShadow
                     , BG.color modalColor
                     , padding 10
                     ]
                        ++ defaultBorder
                    )
                <|
                    column [ fillX, fillY ]
                        [ case modalData.editEnabled of
                            True ->
                                shiftEditElement shift modalData settings

                            False ->
                                shiftViewElement shift modalData settings
                        , case shiftWriteAccess currentEmployee shift of
                            True ->
                                Input.button
                                    ([ defaultShadow, BG.color white, padding 5, centerX ] ++ defaultBorder)
                                    { onPress = Just EventToggleEdit
                                    , label =
                                        case modalData.editEnabled of
                                            False ->
                                                text "Edit"

                                            True ->
                                                text "Back"
                                    }

                            False ->
                                let
                                    employees =
                                        Maybe.withDefault [] model.employees

                                    shiftCreator =
                                        getEmployee employees <| Just shift.supervisorID

                                    creatorName =
                                        case shiftCreator of
                                            Just creator ->
                                                nameToString creator.name FullName

                                            Nothing ->
                                                "Unknown"
                                in
                                el
                                    ([ fillX
                                     , padding 5
                                     ]
                                        ++ defaultBorder
                                    )
                                <|
                                    text <|
                                        "Shift created by "
                                            ++ creatorName
                        ]

        _ ->
            none


vacationModalElement : Model -> VacationData -> Element Message
vacationModalElement model modalData =
    case ( getActiveSettings model, model.currentEmployee ) of
        ( Just activeSettings, Just currentEmployee ) ->
            let
                settings =
                    activeSettings.settings

                vacation =
                    modalData.vacation
            in
            modalOverlay CloseEventModal <|
                el
                    ([ centerX
                     , centerY
                     , defaultShadow
                     , BG.color modalColor
                     , padding 10
                     ]
                        ++ defaultBorder
                    )
                <|
                    column [ fillX, fillY ]
                        [ case modalData.editEnabled of
                            True ->
                                vacationEditElement
                                    model
                                    vacation
                                    modalData
                                    activeSettings

                            False ->
                                vacationViewElement
                                    model
                                    modalData
                                    vacation
                                    activeSettings
                        , case vacationWriteAccess currentEmployee vacation of
                            True ->
                                el [ fillX ] <|
                                    Input.button
                                        ([ defaultShadow, BG.color white, padding 5, centerX ] ++ defaultBorder)
                                        { onPress = Just EventToggleEdit
                                        , label =
                                            case modalData.editEnabled of
                                                False ->
                                                    text "Edit"

                                                True ->
                                                    text "Back"
                                        }

                            False ->
                                let
                                    employees =
                                        Maybe.withDefault [] model.employees

                                    vacationCreator =
                                        getEmployee employees <| Just vacation.employeeID

                                    creatorName =
                                        case vacationCreator of
                                            Just creator ->
                                                nameToString creator.name FullName

                                            Nothing ->
                                                "Unknown"
                                in
                                el
                                    ([ fillX
                                     , padding 5
                                     ]
                                        ++ defaultBorder
                                    )
                                <|
                                    el [ centerX ] <|
                                        text <|
                                            "Vacation requested by "
                                                ++ creatorName
                        ]

        _ ->
            none


dayOfMonthElement : YearMonthDay -> Element Message
dayOfMonthElement day =
    el
        [ Font.size 16
        ]
        (text (String.fromInt day.day))


addEventButton : YearMonthDay -> Element Message
addEventButton day =
    Input.button
        [ BG.color lightGreen
        , Border.rounded 5
        , Font.size 16
        , paddingEach { top = 0, bottom = 0, right = 2, left = 1 }
        ]
        { onPress = Just <| OpenAddEvent day
        , label =
            el [ moveUp 1 ]
                (text "+")
        }


addEventElement : Model -> YearMonthDay -> Element Message
addEventElement model day =
    let
        maybeEmployee =
            model.currentEmployee
    in
    case maybeEmployee of
        Just currentEmployee ->
            modalOverlay CancelAddEvent <|
                el [ centerX, centerY ] <|
                    column
                        ([ BG.color modalColor, defaultShadow, padding 10, spacing 10 ] ++ defaultBorder)
                        [ el [ headerFontSize, BG.color white, padding 5 ] <|
                            text "Add event"
                        , column [ fillX ]
                            [ case currentEmployee.level of
                                Read ->
                                    none

                                _ ->
                                    Input.button
                                        ([ fillX, padding 5, BG.color white ] ++ defaultBorder)
                                        { onPress = Just <| CreateShiftRequest day
                                        , label = el [ centerX ] <| text "Shift"
                                        }
                            , case currentEmployee.level of
                                Read ->
                                    none

                                _ ->
                                    Input.button
                                        ([ fillX, padding 5, BG.color white ] ++ defaultBorder)
                                        { onPress = Just <| CreateCallShiftRequest day
                                        , label = el [ centerX ] <| text "Call Shift"
                                        }
                            , Input.button
                                ([ fillX, padding 5, BG.color white ] ++ defaultBorder)
                                { onPress = Just <| CreateVacationRequest day
                                , label = el [ centerX ] <| text "Vacation"
                                }
                            ]
                        ]

        Nothing ->
            none


dayCompare : YearMonthDay -> YearMonthDay -> Order
dayCompare d1 d2 =
    case compare d1.year d2.year of
        LT ->
            LT

        EQ ->
            case compare d1.month d2.month of
                LT ->
                    LT

                EQ ->
                    compare d1.day d2.day

                GT ->
                    GT

        GT ->
            GT


getDayState maybe1 maybe2 =
    case ( maybe1, maybe2 ) of
        ( Just d1, Just d2 ) ->
            case dayCompare d1 d2 of
                LT ->
                    Past

                EQ ->
                    Today

                GT ->
                    Future

        ( _, _ ) ->
            None


type DayState
    = None
    | Past
    | Today
    | Future


viewDayInMonth :
    Model
    -> YearMonthDay
    -> CombinedSettings
    -> Maybe YearMonthDay
    -> Element Message
viewDayInMonth model today combined maybeYMD =
    let
        dayState =
            getDayState maybeYMD (Just today)

        employees =
            Maybe.withDefault [] model.employees

        viewEmployees =
            getViewEmployees
                employees
                combined.settings.viewEmployees

        currentEmployee =
            model.currentEmployee

        settings =
            combined.settings
    in
    case maybeYMD of
        Just day ->
            el
                (dayStyle dayState)
                (column
                    [ fillX
                    , fillY
                    , paddingXY 5 0
                    ]
                    ([ row
                        [ padding 5
                        ]
                        [ dayOfMonthElement day
                        , addEventButton day
                        ]
                    ]
                    ++ (case settings.showShifts of
                        True ->
                            [ shiftColumn model viewEmployees combined day
                            ]

                        False ->
                            [])
                    ++ (case settings.showCallShifts of
                        True ->
                            [ dividerBar grey
                            , callShiftColumn model viewEmployees combined day
                            ]

                        False ->
                            [])
                    ++ (case settings.showVacations of
                        True ->
                            [ dividerBar grey
                            , vacationColumn model viewEmployees combined day
                            ]

                        False ->
                            [])
                    )
                )

        Nothing ->
            el
                (dayStyle dayState)
            <|
                column [ fillX ] []


weekDaysView :
    Model
    -> YearMonthDay
    -> CombinedSettings
    -> Week
    -> Element Message
weekDaysView model today combined week =
    row
        [ fillX
        , fillY
        , spacing 0
        , Border.widthEach { top = 0, bottom = 1, right = 0, left = 0 }
        ]
        (week
            |> Array.toList
            |> List.map (viewDayInMonth model today combined)
        )


searchRadio :
    String
    -> String
    -> String
    -> (String -> Message)
    -> Element Message
    -> (a -> Message)
    -> Maybe a
    -> String
    -> List (Input.Option a Message)
    -> Element Message
searchRadio searchID searchLabel searchText searchChangeMsg confirmed radioChangeMsg radioSelected radioLabel radioOptions =
    column
        [ spacing 15
        , paddingXY 0 15
        ]
        [ Input.search
            [ fillX
            , defaultShadow
            , centerX
            , htmlAttribute (HtmlAttr.id searchID)
            , onRight confirmed
            ]
            { onChange = searchChangeMsg
            , text = searchText
            , placeholder = Nothing
            , label =
                Input.labelAbove
                    [ centerX, padding 2 ]
                    (text searchLabel)
            }
        , Input.radio
            ([ clipY
             , scrollbarY
             , height (px 150)
             , fillX
             ]
                ++ defaultBorder
            )
            { onChange = radioChangeMsg
            , selected = radioSelected
            , label = Input.labelHidden radioLabel
            , options = radioOptions
            }
        ]


settingsToOption : CombinedSettings -> Input.Option Int Message
settingsToOption combined =
    let
        settings =
            combined.settings
    in
    Input.option
        settings.id
        (el [ fillX ] <|
            el
                ([ defaultShadow
                 , BG.color lightGrey
                 , centerX
                 , padding 5
                 ]
                    ++ defaultBorder
                )
            <|
                text settings.name
        )


colorDisplay : EmployeeColor -> Element Message
colorDisplay c =
    let
        pair =
            employeeColor c

        lightRgb =
            pair.light

        darkRgb =
            pair.dark

        light =
            fromRgb lightRgb

        dark =
            fromRgb darkRgb
    in
    el [ padding 2 ] <|
        el
            [ width <| px 20
            , height <| px 20
            , BG.color light
            , Border.color dark
            , Border.width 2
            , Border.rounded 10
            ]
            none


colorSelectOpenButton : Employee -> EmployeeColor -> Element Message
colorSelectOpenButton employee color =
    Input.button []
        { onPress = Just <| OpenEmployeeColorSelector employee
        , label = colorDisplay color
        }


colorOpt c =
        Input.optionWith c
            (\o ->
                case o of
                    Input.Selected ->
                        el 
                        [ Border.width 1
                        , Border.color black
                        , Border.rounded 3
                        , Border.innerGlow (rgb 0.6 0.95 0.6) 1
                        ] <| colorDisplay c

                    _ ->
                        colorDisplay c
            )

colorOptions =
    [ colorOpt Red
    , colorOpt LightRed
    , colorOpt Green
    , colorOpt LightGreen
    , colorOpt Blue
    , colorOpt LightBlue
    , colorOpt Yellow
    , colorOpt LightYellow
    , colorOpt Grey
    , colorOpt LightGrey
    -- , colorOpt Brown
    , colorOpt Purple
    ]

colorSelector : Employee -> EmployeeColor -> Element Message
colorSelector employee color =
    Input.radioRow
        ([ BG.color white
         , defaultShadow
         ]
            ++ defaultBorder
        )
        { onChange = ChooseEmployeeColor employee
        , selected = Just color
        , label = Input.labelHidden "Employee color"
        , options = colorOptions
        }


employeeToColorPicker : Employee -> EmployeeColor -> Bool -> Element Message
employeeToColorPicker employee color selectOpen =
    case selectOpen of
        True ->
            colorSelector employee color

        False ->
            colorSelectOpenButton employee color


employeeToCheckbox : CombinedSettings -> Employee -> Element Message
employeeToCheckbox combined employee =
    let
        filtered =
            List.filter
                (\i -> i == employee.id)
                combined.settings.viewEmployees

        first =
            List.head filtered
    in
    Input.checkbox
        ([] ++ defaultBorder)
        { onChange = EmployeeViewCheckbox employee.id
        , icon = Input.defaultCheckbox
        , checked =
            case first of
                Just found ->
                    True

                Nothing ->
                    False
        , label =
            Input.labelRight []
                (text <| nameToString employee.name FullName)
        }


basicButton :
    List (Attribute Message)
    -> Color
    -> Maybe Message
    -> String
    -> Element Message
basicButton attrs color onPress label =
    Input.button
        ([ BG.color color
         , padding 5
         , defaultShadow
         ]
            ++ attrs
        )
        { onPress = onPress
        , label = text label
        }


selectViewElement : Model -> Element Message
selectViewElement model =
    modalOverlay CloseViewSelect <|
        column
            ([ centerX
             , centerY
             , BG.color lightGrey
             , defaultShadow
             , spacing 5
             ]
                ++ defaultBorder
            )
            [ -- title text
              el
                [ fillX
                , fillY
                , padding 10
                ]
              <|
                el
                    [ centerX
                    , centerY
                    , BG.color white
                    , headerFontSize
                    , padding 15
                    ]
                <|
                    text "Views:"
            , -- active view select
              el
                [ fillX
                , padding 10
                ]
              <|
                Input.radio [ centerX ]
                    { onChange = ChooseActiveView
                    , options =
                        List.map
                            settingsToOption
                        <|
                            Maybe.withDefault [] model.settingsList
                    , selected = model.activeSettings
                    , label =
                        Input.labelAbove [ fillX ] <|
                            el [ centerX ] <|
                                text "Select view:"
                    }
            , -- navigation
              row
                ([ fillX, spacing 15, padding 10 ]
                    ++ defaultBorder
                )
                [ basicButton
                    []
                    yellow
                    (Just DuplicateView)
                    "Copy"
                , basicButton
                    []
                    red
                    (Just RemoveView)
                    "Delete"
                ]
            ]


yellow =
    rgb 0.7 0.7 0.2


editViewElement : Model -> ViewEditData -> Maybe CombinedSettings -> Maybe (List Employee) -> Element Message
editViewElement model editData maybeSettings employees =
    case maybeSettings of
        Just combined ->
            let
                settings =
                    combined.settings
            in
            modalOverlay CloseViewEdit <|
                column
                    ([ centerX
                     , centerY
                     , BG.color lightGrey
                     , padding 10
                     , defaultShadow
                     ]
                        ++ defaultBorder
                    )
                    [ -- header text
                      el
                        [ fillX
                        , headerFontSize
                        , padding 10
                        , BG.color white
                        , alignTop
                        ]
                      <|
                        el [ centerX ] <|
                            text "Edit view"
                    , el [ fillX ] <|
                        Input.text [ centerX ]
                            { onChange = UpdateViewName
                            , text = settings.name
                            , placeholder = Nothing
                            , label = Input.labelAbove [] <| text "View Name:"
                            }
                    , -- View type, hour format, last name style
                      row
                        ([ padding 10
                         , alignTop
                         ]
                            ++ defaultBorder
                        )
                        [ column ([ alignTop, paddingXY 5 0, fillX ] ++ defaultBorder)
                            [ el ([ BG.color white, padding 5, centerX ] ++ defaultBorder) <| text "View type:"
                            , el [ fillX ] <|
                                Input.radio
                                    ([ centerX
                                     ]
                                        ++ defaultBorder
                                    )
                                    { onChange = UpdateViewType
                                    , options =
                                        [ Input.option MonthView (text "Month view")
                                        , Input.option WeekView (text "Week view")
                                        , Input.option DayView (text "Day view")
                                        , Input.option AltDayView (text "Alternate day view")
                                        ]
                                    , selected = Just settings.viewType
                                    , label = Input.labelHidden "View type"
                                    }
                            ]
                        , column ([ alignTop, paddingXY 5 0, fillX ] ++ defaultBorder)
                            [ el ([ BG.color white, padding 5, centerX ] ++ defaultBorder) <| text "Hour format:"
                            , el [ fillX ] <|
                                Input.radio
                                    ([ centerX
                                     ]
                                        ++ defaultBorder
                                    )
                                    { onChange = UpdateHourFormat
                                    , options =
                                        [ Input.option Hour12 <| text "12-hour time"
                                        , Input.option Hour24 <| text "24-hour time"
                                        ]
                                    , selected = Just settings.hourFormat
                                    , label = Input.labelHidden "Hour format:"
                                    }
                            ]
                        , column ([ alignTop, paddingXY 5 0, fillX ] ++ defaultBorder)
                            [ el ([ BG.color white, padding 5, centerX ] ++ defaultBorder) <| text "Last name style:"
                            , el [ fillX ] <|
                                Input.radio
                                    ([ centerX
                                     ]
                                        ++ defaultBorder
                                    )
                                    { onChange = UpdateLastNameStyle
                                    , options =
                                        [ Input.option FullName <| text "Full name"
                                        , Input.option FirstInitial <| text "First initial"
                                        , Input.option Hidden <| text "Hidden"
                                        ]
                                    , selected = Just settings.lastNameStyle
                                    , label = Input.labelHidden "Last name style:"
                                    }
                            ]
                        ]
                    , row
                        ([ padding 10
                         , alignTop
                         ]
                            ++ defaultBorder
                        )
                        [ column ([ alignTop, paddingXY 5 0, fillX ] ++ defaultBorder)
                            [ el ([ BG.color white, padding 5, centerX ] ++ defaultBorder) <| text "Minutes:"
                            , el [ fillX ] <|
                                Input.radio
                                    ([ centerX ] ++ defaultBorder)
                                    { onChange = UpdateShowMinutes
                                    , options =
                                        [ Input.option True <| text "Show"
                                        , Input.option False <| text "Hide"
                                        ]
                                    , selected = Just settings.showMinutes
                                    , label = Input.labelHidden "Minutes"
                                    }
                            ]
                        , column ([ alignTop, paddingXY 5 0, fillX ] ++ defaultBorder)
                            [ el ([ BG.color white, padding 5, centerX ] ++ defaultBorder) <| text "Shifts:"
                            , el [ fillX ] <|
                                Input.radio
                                    ([ centerX ] ++ defaultBorder)
                                    { onChange = UpdateShowShifts
                                    , options =
                                        [ Input.option True <| text "Show"
                                        , Input.option False <| text "Hide"
                                        ]
                                    , selected = Just settings.showShifts
                                    , label = Input.labelHidden "Shifts"
                                    }
                            ]
                        , column ([ alignTop, paddingXY 5 0, fillX ] ++ defaultBorder)
                            [ el ([ BG.color white, padding 5, centerX ] ++ defaultBorder) <| text "Call Shifts:"
                            , el [ fillX ] <|
                                Input.radio
                                    ([ centerX ] ++ defaultBorder)
                                    { onChange = UpdateShowCallShifts
                                    , options =
                                        [ Input.option True <| text "Show"
                                        , Input.option False <| text "Hide"
                                        ]
                                    , selected = Just settings.showCallShifts
                                    , label = Input.labelHidden "Call Shifts"
                                    }
                            ]
                        , column ([ alignTop, paddingXY 5 0, fillX ] ++ defaultBorder)
                            [ el ([ BG.color white, padding 5, centerX ] ++ defaultBorder) <| text "Vacations:"
                            , el [ fillX ] <|
                                Input.radio
                                    ([ centerX ] ++ defaultBorder)
                                    { onChange = UpdateShowVacations
                                    , options =
                                        [ Input.option True <| text "Show"
                                        , Input.option False <| text "Hide"
                                        ]
                                    , selected = Just settings.showVacations
                                    , label = Input.labelHidden "Vacations"
                                    }
                            ]
                        ]
                    , -- employee selection
                      column
                        ([ fillX
                         , spacing 5
                         , padding 10
                         , BG.color white
                         , height <| px 200
                         , clipY
                         , scrollbarY
                         ]
                            ++ defaultBorder
                        )
                      <|
                        List.map
                            (\e ->
                                let
                                    color = getEmployeeColor model (Just e.id)

                                    selectOpen =
                                        case editData.colorSelect of
                                            Just colorEmp ->
                                                colorEmp.id == e.id

                                            Nothing ->
                                                False
                                in
                                row [ fillX, spacingXY 30 0 ]
                                    [ employeeToCheckbox combined e
                                    , employeeToColorPicker e color selectOpen
                                    ]
                            )
                            (Maybe.withDefault [] employees)
                    ]

        Nothing ->
            none


green =
    rgb 0.2 0.9 0.2


red =
    rgb 0.9 0.2 0.2


viewMonthRows :
    Model
    -> Month
    -> YearMonthDay
    -> CombinedSettings
    -> Element Message
viewMonthRows model month today combined =
    column
        [ width fill
        , height fill
        , spacing 1
        ]
        (Array.toList
            (Array.map
                (weekDaysView
                    model
                    today
                    combined
                )
                month
            )
        )


fillX =
    width fill


fillY =
    height fill


borderR =
    Border.widthEach
        { top = 0, bottom = 0, left = 0, right = 1 }


borderL =
    Border.widthEach
        { top = 0, bottom = 0, left = 1, right = 0 }


makeWeekFromYMD : YearMonthDay -> Week
makeWeekFromYMD ymd =
    let
        focusWeekday =
            toWeekday ymd - 1

        dayRange =
            List.range (ymd.day - focusWeekday) (ymd.day + (6 - focusWeekday))

        ymdRange =
            List.map (\d -> Just <| convertYMIntToYMD ymd.year ymd.month d) dayRange
    in
    Array.fromList ymdRange


hourBGFromInt : Int -> Element Message
hourBGFromInt i =
    el
        [ Border.color <| rgba 0.5 0.5 0.5 0.5
        , Border.widthEach
            { right = 1
            , left = 0
            , top = 0
            , bottom = 0
            }
        , fillX
        , fillY
        ]
        none


viewDay :
    Model
    -> YearMonthDay
    -> YearMonthDay
    -> CombinedSettings
    -> Element Message
viewDay model today viewDate combined =
    let
        dateFormat =
            Just <| YMDStringSettings LongDate True

        dateStr =
            ymdToString viewDate dateFormat

        dayState =
            getDayState (Just viewDate) (Just today)

        employees =
            Maybe.withDefault [] model.employees

        settings =
            combined.settings

        viewEmployees =
            getViewEmployees
                employees
                settings.viewEmployees

        hourRange =
            List.range 0 23
    in
    column
        ([ fillX
         , fillY
         , behindContent <|
            row
                [ fillX
                , fillY
                ]
                (List.map hourBGFromInt hourRange)
         ]
            ++ defaultBorder
        )
        ([ column
            [ fillX
            , spacing 5
            , paddingXY 0 5
            , BG.color white
            , Border.color black
            , Border.widthEach
                { bottom = 1
                , top = 0
                , left = 0
                , right = 0
                }
            ]
            [ row
                [ centerX
                , spaceEvenly
                ]
                [ Input.button [ paddingXY 50 0 ]
                    { onPress = Just PriorDay
                    , label = text "<<--"
                    }
                , el [ centerX ] <| text dateStr
                , Input.button [ paddingXY 50 0 ]
                    { onPress = Just NextDay
                    , label = text "-->>"
                    }
                ]
            , Input.button
                [ BG.color lightGreen
                , Border.rounded 3
                , centerX
                , padding 4
                , defaultShadow
                ]
                { onPress = Just <| OpenAddEvent viewDate
                , label = text "Add Event"
                }
            , row
                [ fillX
                , spaceEvenly
                ]
                [ el [ fillX, borderL ] <| el [ alignLeft ] <| text "12am"
                , el [ fillX, borderL ] <| el [ alignLeft ] <| text "3am"
                , el [ fillX, borderL ] <| el [ alignLeft ] <| text "6am"
                , el [ fillX, borderL ] <| el [ alignLeft ] <| text "9am"
                , el [ fillX, borderL ] <| el [ alignLeft ] <| text "12pm"
                , el [ fillX, borderL ] <| el [ alignLeft ] <| text "3pm"
                , el [ fillX, borderL ] <| el [ alignLeft ] <| text "6pm"
                , el [ fillX, borderL ] <| el [ alignLeft ] <| text "9pm"
                ]
            ]
        ]
        ++ (case combined.settings.showShifts of
            True ->
                [shiftHoursColumn model viewEmployees combined viewDate]

            False ->
                [])
        ++ (case combined.settings.showCallShifts of
            True ->
                [ 
                  dividerBar grey
                , el 
                    ([centerX, BG.color white, padding 3] ++ defaultBorder) 
                    <| text "On Call"
                , callShiftHoursColumn model viewEmployees combined viewDate
                ]

            False ->
                [])
        ++ (case settings.showVacations of
            True ->
                [vacationColumn model viewEmployees combined viewDate]

            False ->
                [])
        )
        

viewDayAlt :
    Model
    -> YearMonthDay
    -> YearMonthDay
    -> CombinedSettings
    -> Element Message
viewDayAlt model today viewDate combined =
    let
        dateFormat =
            Just <| YMDStringSettings LongDate True

        dateStr =
            ymdToString viewDate dateFormat

        dayState =
            getDayState (Just viewDate) (Just today)

        employees =
            Maybe.withDefault [] model.employees

        settings =
            combined.settings

        viewEmployees =
            getViewEmployees
                employees
                settings.viewEmployees

        hourRange =
            List.range 0 23
    in
    column
        ([ fillX
         , fillY
         , padding 20
         ]
            ++ defaultBorder
        )
        ([ column
            [ fillX
            , spacing 5
            , paddingXY 0 5
            , BG.color white
            , Border.color black
            , Border.widthEach
                { bottom = 1
                , top = 0
                , left = 0
                , right = 0
                }
            ]
            [ row
                [ centerX
                , spaceEvenly
                ]
                [ Input.button [ paddingXY 50 0 ]
                    { onPress = Just PriorDay
                    , label = text "<<--"
                    }
                , el [ centerX ] <| text dateStr
                , Input.button [ paddingXY 50 0 ]
                    { onPress = Just NextDay
                    , label = text "-->>"
                    }
                ]
            , Input.button
                [ BG.color lightGreen
                , Border.rounded 3
                , centerX
                , padding 4
                , defaultShadow
                ]
                { onPress = Just <| OpenAddEvent viewDate
                , label = text "Add Event"
                }
            ]
        ]
        ++ (case combined.settings.showShifts of
            True ->
                [shiftColumn model viewEmployees combined viewDate]

            False ->
                [])
        ++ (case combined.settings.showCallShifts of
            True ->
                [ 
                  dividerBar grey
                , el 
                    ([centerX, BG.color white, padding 3] ++ defaultBorder) 
                    <| text "On Call"
                , callShiftColumn model viewEmployees combined viewDate
                ]

            False ->
                [])
        ++ (case settings.showVacations of
            True ->
                [vacationColumn model viewEmployees combined viewDate]

            False ->
                [])
        )


viewWeek :
    Model
    -> YearMonthDay
    -> Week
    -> CombinedSettings
    -> Element Message
viewWeek model today week combined =
    let
        maybeGetStart =
            Array.get 0 week

        maybeGetEnd =
            Array.get 6 week

        dateFormat =
            Just <| YMDStringSettings LongDate False

        startStr =
            case maybeGetStart of
                Just maybeStart ->
                    case maybeStart of
                        Just start ->
                            ymdToString start dateFormat

                        Nothing ->
                            "?"

                Nothing ->
                    "?"

        endStr =
            case maybeGetEnd of
                Just maybeEnd ->
                    case maybeEnd of
                        Just end ->
                            ymdToString end dateFormat

                        Nothing ->
                            "?"

                Nothing ->
                    "?"
    in
    column
        [ fillX
        , fillY
        ]
        [ row
            [ centerX
            , spaceEvenly
            ]
            [ Input.button [ paddingXY 50 0 ]
                { onPress = Just PriorWeek
                , label = text "<<--"
                }
            , el [ centerX ] <| text <| startStr ++ " to " ++ endStr
            , Input.button [ paddingXY 50 0 ]
                { onPress = Just NextWeek
                , label = text "-->>"
                }
            ]
        , viewDaysOfWeekHeader
        , weekDaysView model today combined week
        ]


viewMonth :
    Model
    -> YearMonthDay
    -> Month
    -> CombinedSettings
    -> Element Message
viewMonth model today month combined =
    let
        viewDate =
            combined.settings.viewDate
    in
    column
        [ fillX
        , fillY
        ]
        [ -- Month Header
          row
            [ centerX
            , spaceEvenly
            ]
            [ -- Prior Month button
              Input.button [ paddingXY 50 0 ]
                { onPress = Just PriorMonth
                , label = text "<<--"
                }
            , -- View Date Display
              el [] <|
                text
                    (monthNumToString viewDate.month
                        ++ " "
                        ++ String.fromInt viewDate.year
                    )
            , -- Next Month Button
              Input.button [ paddingXY 50 0 ]
                { onPress = Just NextMonth
                , label = text "-->>"
                }
            ]
        , -- Days of week display
          viewDaysOfWeekHeader
        , viewMonthRows model month today combined
        ]


viewDaysOfWeekHeader =
    row
        [ fillX
        , height shrink
        , Border.widthEach
            { top = 1, bottom = 1, left = 0, right = 0 }
        ]
        [ el [ fillX, borderL ] (el [ centerX ] (text "Sunday"))
        , el [ fillX, borderL ] (el [ centerX ] (text "Monday"))
        , el [ fillX, borderL ] (el [ centerX ] (text "Tuesday"))
        , el [ fillX, borderL ] (el [ centerX ] (text "Wednesday"))
        , el [ fillX, borderL ] (el [ centerX ] (text "Thursday"))
        , el [ fillX, borderL ] (el [ centerX ] (text "Friday"))
        , el [ fillX, borderL ] (el [ centerX ] (text "Saturday"))
        ]


viewAccountModal : Model -> AccountModalData -> Element Message
viewAccountModal model modalData =
    case model.currentEmployee of
        Just currentEmployee ->
            modalOverlay CloseAccountModal <|
            column
            [ centerX
            , centerY
            , BG.color modalColor
            , spacing 5
            , padding 10
            , defaultShadow
            ]
            [ el [padding 10, centerX] <| text "Account Settings"
            , row
                []
                [ text "Select default color: "
                , case modalData.colorSelectOpen of
                    False ->
                        Input.button
                            []
                            { onPress = Just 
                                <| OpenDefaultColorSelector
                            , label = row []
                                [ colorDisplay currentEmployee.defaultColor
                                ]
                            }
                    True ->
                        Input.radioRow
                            ([ BG.color white
                            , defaultShadow
                            ]
                                ++ defaultBorder
                            )
                            { onChange = UpdateAccountDefaultColor
                            , selected = Just currentEmployee.defaultColor
                            , label = Input.labelHidden "Employee color"
                            , options = colorOptions
                            }
                ]
            , Input.text
                [ Events.onLoseFocus AccountModalUnfocusPhoneNumber ]
                { onChange = UpdateAccountPhoneNumber
                , text = modalData.phoneNumber
                , placeholder = Nothing
                , label = Input.labelLeft [] <| text "Phone number:"
                }
            , column
                defaultBorder
                [ Input.currentPassword
                    []
                    { onChange = UpdateAccountOldPassword
                    , text = modalData.oldPassword
                    , placeholder = Nothing
                    , label = Input.labelLeft [] <| text "Current password:"
                    , show = False
                    }
                , Input.newPassword
                    []
                    { onChange = UpdateAccountNewPassword
                    , text = modalData.newPassword
                    , placeholder = Nothing
                    , label = Input.labelLeft [] <| text "New password:"
                    , show = False
                    }
                , Input.newPassword
                    []
                    { onChange = UpdateAccountNewPasswordAgain
                    , text = modalData.newPasswordAgain
                    , placeholder = Nothing
                    , label = Input.labelLeft [] <| text "New password again:"
                    , show = False
                    }
                , Input.button
                    ([ padding 5
                    , centerX
                    , BG.color white
                    , defaultShadow
                    ] ++ defaultBorder)
                    { onPress = Just ChangePassword
                    , label = text "Change password"
                    }
                ]
            , el
                (
                [ fillX
                , padding 5
                -- , BG.color white
                ] ++ defaultBorder)
                <| el [centerX] <| text modalData.status
            ]

        Nothing ->
            text "No employee logged in"

viewModal : Model -> Element Message
viewModal model =
    case model.page of
        CalendarPage page ->
            case page.modal of
                NoModal ->
                    none

                AddEventModal day ->
                    addEventElement model day

                ShiftModal modalData ->
                    shiftModalElement model modalData

                VacationModal modalData ->
                    vacationModalElement model modalData

                ViewSelectModal ->
                    selectViewElement model

                ViewEditModal modalData ->
                    editViewElement model modalData (getActiveSettings model) model.employees

                EmployeeEditor modalData ->
                    viewEmployeeEditor model modalData

                VacationApprovalModal ->
                    vacationApprovalModal model
                
                AccountModal modalData ->
                    viewAccountModal model modalData

        _ ->
            text "Error: viewing modal from wrong page"


viewCalendar : Model -> Element Message
viewCalendar model =
    case
        ( model.here, model.posixNow, getActiveSettings model )
    of
        ( Just here, Just now, Just active ) ->
            let
                today =
                    getTime now here

                viewDate =
                    active.settings.viewDate
            in
            case active.settings.viewType of
                MonthView ->
                    let
                        month =
                            makeGridFromMonth
                                (YearMonth viewDate.year viewDate.month)
                    in
                    column
                        [ width fill
                        , height fill
                        , inFront (viewModal model)
                        ]
                        [ viewMonth
                            model
                            today
                            month
                            active
                        , viewCalendarFooter model.currentEmployee
                        ]

                WeekView ->
                    let
                        week =
                            makeWeekFromYMD viewDate
                    in
                    column [ fillX, fillY, inFront (viewModal model) ]
                        [ viewWeek model today week active
                        , viewCalendarFooter model.currentEmployee
                        ]

                DayView ->
                    column [ fillX, fillY, inFront (viewModal model) ]
                        [ viewDay model today viewDate active
                        , viewCalendarFooter model.currentEmployee
                        ]

                AltDayView ->
                    column [ fillX, fillY, inFront (viewModal model) ]
                        [ viewDayAlt model today viewDate active
                        , viewCalendarFooter model.currentEmployee
                        ]

        _ ->
            text "Loading..."


view : Model -> Browser.Document Message
view model =
    case model.page of
        LoginPage _ ->
            toDocument (viewLogin model)

        CalendarPage _ ->
            toDocument (viewCalendar model)
