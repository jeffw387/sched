import { Config } from "./config";
import { ICRUD } from "./icrud";

const test_data: Config[] = [new Config(0, 0), new Config(1, 1)];

export class Configs {
  configs?: Config[] = test_data;
}

export class MockConfigs implements ICRUD<Config> {
  get(): Config[] {
    return this.configs;
  }
  add(t: Config): void {
    throw new Error("Method not implemented.");
  }
  update(t: Config): void {
    throw new Error("Method not implemented.");
  }
  remove(t: Config): void {
    throw new Error("Method not implemented.");
  }
  configs: Config[] = test_data;


  
}

