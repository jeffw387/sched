module Api exposing (..)
import Url.Builder as UB

loginPage = UB.absolute ["sched", "login"] []
calendarPage = UB.absolute ["sched", "calendar"] []
settingsPage = UB.absolute ["sched", "settings"] []
loginRequest = UB.absolute ["sched", "login_request"] []
getEmployees = UB.absolute ["sched", "get_employees"] []
getShifts = UB.absolute ["sched", "get_shifts"] []
