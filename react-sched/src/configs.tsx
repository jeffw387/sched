import { Config } from "./config";

export class Configs {
  configs?: Config[] = test_data;
  view_date: Date = new Date(Date.now());
}

const test_data: Config[] = [
  new Config(0, 0),
  new Config(1, 1)
];

