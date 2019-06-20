import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';
import { HttpClientModule } from '@angular/common/http';
import { RouterModule, Routes } from '@angular/router';
import { ReactiveFormsModule } from '@angular/forms';

import { AppComponent } from './app.component';
import { LoginComponent } from './login/login.component';
import { CalendarComponent } from './calendar/calendar.component';
import { DayComponent } from './calendar/day/day.component';
import { WeekComponent } from './calendar/week/week.component';
import { MonthComponent } from './calendar/month/month.component';
import { CalendarNavComponent } from './calendar/calendar-nav/calendar-nav.component';
import { PageSelectComponent } from './page-select/page-select.component';

const appRoutes: Routes = [
  {
    path: '',
    redirectTo: '/sched',
    pathMatch: 'full'
  },
  { 
    path: 'sched',
    component: AppComponent,
    children: [
      {
        path: '',
        component: PageSelectComponent
      },
      {
        path: 'login',
        component: LoginComponent
      },
      {
        path: 'calendar',
        component: CalendarComponent,
        children: [
          {
            path: 'day',
            component: DayComponent
          },
          {
            path: 'week',
            component: WeekComponent
          },
          {
            path: 'month',
            component: MonthComponent
          },
        ]
      },
    ]
  },
]

@NgModule({
  declarations: [
    AppComponent,
    LoginComponent,
    CalendarComponent,
    DayComponent,
    WeekComponent,
    MonthComponent,
    CalendarNavComponent,
    PageSelectComponent
  ],
  imports: [
    BrowserModule,
    HttpClientModule,
    ReactiveFormsModule,
    RouterModule.forRoot(
      appRoutes,
      {
        enableTracing: true
      })
  ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule { }
