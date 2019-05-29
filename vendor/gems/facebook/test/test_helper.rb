ENV['RAILS_ENV'] ||= 'test'

require_relative 'helpers/simple_cov_setup'
require 'rails/test_help'

require 'rubygems'
require 'bundler'
Bundler.setup
