#!/bin/bash
cargo build --target wasm32-unknown-unknown
wasm-bindgen ../target/wasm32-unknown-unknown/debug/sched_client_seed.wasm --no-modules --out-dir ./pkg --out-name package