#![feature(trait_alias)]
#[macro_use]
extern crate diesel;
#[macro_use]
pub mod enum_helper;
pub mod api;
pub mod datetime;
pub mod db;
pub mod employee;
pub mod env;
pub mod message;
pub mod schema;
pub mod settings;
pub mod shift;
