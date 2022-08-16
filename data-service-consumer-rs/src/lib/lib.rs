#![feature(generic_associated_types)]

#[macro_use]
extern crate diesel;

pub mod config;
pub mod consumer;
pub mod db;
pub mod error;
pub mod models;
pub mod schema;
mod tuple_len;
pub mod waves;
