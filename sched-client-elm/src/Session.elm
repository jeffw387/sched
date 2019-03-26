module Session exposing (..)
import Browser.Navigation as Nav
import Url

type ViewType =
  Month |
  Week |
  Day

type HourFormat =
  Hour12 |
  Hour24

type alias Settings =
  {
    viewType : ViewType,
    hourFormat : HourFormat
  }

type alias Session =
  {
    url : Url.Url,
    navkey : Nav.Key,
    settings : Settings
  }