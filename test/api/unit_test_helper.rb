ENV['RAILS_ENV'] = 'test'
require File.expand_path('../../../lib/custom_request_store', __FILE__)
require File.expand_path('../../../test/helpers/simple_cov_setup', __FILE__)

def load_environment
  puts 'Switching ON API Layer'
  CustomRequestStore.store[:api_request] = true
  CustomRequestStore.store[:private_api_request] = true
  changed = change_api_layer(true)
  private_changed = false
  if $PROGRAM_NAME =~ /public_api_test_suite.rb/
    private_changed = change_private_api_layer(false)
  end

  if !defined?($env_loaded) || $env_loaded != true
    require File.expand_path('../../../config/environment', __FILE__)
  else
    puts "Skipping loading environment since its already loaded"
  end
ensure
    puts 'Switching OFF API Layer'
    change_api_layer(false) if changed
    change_private_api_layer(true) if private_changed
end

def change_api_layer(new_value)
  if (new_value && CustomRequestStore.read(:api_request)) || (new_value.is_a?(FalseClass) && !CustomRequestStore.read(:api_request))
    new_value ? puts('API Layer already switched ON') : puts('API Layer already switched OFF')
    return false
  else
    CustomRequestStore.store[:api_request] = true
    return true
  end
end

def change_private_api_layer(new_value)
  if (new_value && CustomRequestStore.read(:private_api_request)) || (new_value.is_a?(FalseClass) && !CustomRequestStore.read(:private_api_request))
    new_value ? puts('Private API Layer already switched ON') : puts('Private API Layer already switched OFF')
    return true
  else
    CustomRequestStore.store[:private_api_request] = false
    return false
  end
end

load_environment
require File.expand_path('../../../test/api/helpers/mock_test_validation', __FILE__)
require 'rails/test_help'
require 'minitest/rails'
require 'minitest/reporters'
require 'json_expressions/minitest'
include ActiveSupport::Rescuable

Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new, Minitest::Reporters::JUnitReporter.new('test/reports')]

$env_loaded = true # To make sure we don't load the environment again
