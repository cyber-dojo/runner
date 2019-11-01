#!/bin/bash

export RACK_ENV=production
export RUBYOPT='-W2'
rackup --warn --port 4597 config.ru
