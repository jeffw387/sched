import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';

import { CredentialsService } from '../credentials.service'

@Component({
  selector: 'app-page-select',
  templateUrl: './page-select.component.html',
  styleUrls: ['./page-select.component.css']
})
export class PageSelectComponent implements OnInit {

  constructor(
    private cred: CredentialsService,
    private router: Router
  ) { }

  ngOnInit() {
    if (this.cred.check()) {
      this.router.navigate(['sched', 'calendar'])
    }
    else {
      this.router.navigate(['sched', 'login'])
    }
  }

}
