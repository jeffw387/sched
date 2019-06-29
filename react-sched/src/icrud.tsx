export interface ICRUD<T> {
  get(): T[];
  add(t: T): void;
  update(t: T): void;
  remove(t: T): void;
}