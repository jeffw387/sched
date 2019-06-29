import { DateTime } from "luxon";

export class ViewDate {
  private view_date: DateTime = DateTime.fromMillis(Date.now());
  get() {
    return this.view_date;
  }

  addDays(days: number) {
    this.view_date = this.view_date.plus({ days: days });
  }
}