ENV['RAILS_ENV'] = 'test'
require File.expand_path('../../../test/api/helpers/simple_cov_setup', __FILE__)
require File.expand_path('../../../config/environment', __FILE__)

require 'rails/test_help'
require 'minitest/rails'
require 'minitest/reporters'
require 'json_expressions/minitest'
include ActiveSupport::Rescuable

Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new, Minitest::Reporters::JUnitReporter.new('test/api/reports')]
