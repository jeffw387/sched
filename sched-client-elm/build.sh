#!/bin/bash

./node_modules/elm/bin/elm make src/Main.elm --output ../sched-server/static/index.js --optimize
