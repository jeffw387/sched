import { Config } from "./config";
import { ICRUD } from "./icrud";

const test_data: Config[] = [
  {
    ...new Config(0, 0),
    ...{view_employees: [0, 1],
        show_minutes: true},
  },
  {
    ...new Config(1, 1),
    ...{view_employees: [0, 1],
        show_minutes: true},
  }
];

export class Configs {
  configs?: Config[] = test_data;
}

export class MockConfigs implements ICRUD<Config> {
  add(t: Config): ICRUD<Config> {
    throw new Error("Method not implemented.");
  }
  update(t: Config): ICRUD<Config> {
    throw new Error("Method not implemented.");
  }
  remove(t: Config): ICRUD<Config> {
    throw new Error("Method not implemented.");
  }
  get(): Config[] {
    return this.configs;
  }
  configs: Config[] = test_data;
}
