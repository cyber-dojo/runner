#!/usr/bin/env puma
# frozen_string_literal: true

environment 'production'
rackup "#{__dir__}/config.ru"
