#!/usr/bin/env puma
require 'etc'

environment 'production'
rackup "#{__dir__}/config.ru"
workers(Etc.nprocessors)
