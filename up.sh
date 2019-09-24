#!/bin/bash

export RACK_ENV=production
export RUBYOPT='-W2'
rackup --warn config.ru
