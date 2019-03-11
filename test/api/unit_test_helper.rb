ENV['RAILS_ENV'] = 'test'
file_name = File.expand_path('../../../config/infra_layer.yml', __FILE__)
require File.expand_path('../../../test/helpers/simple_cov_setup', __FILE__)

def load_environment(file_name)
  puts 'Switching ON API Layer'
  changed = change_api_layer(file_name, true)
  private_changed = false
  if $PROGRAM_NAME =~ /public_api_test_suite.rb/
    private_changed = change_private_api_layer(file_name, false)
  end

  if !defined?($env_loaded) || $env_loaded != true
    require File.expand_path('../../../config/environment', __FILE__)
  else
    puts "Skipping loading environment since its already loaded"
  end
ensure
    puts 'Switching OFF API Layer'
    change_api_layer(file_name, false) if changed
    change_private_api_layer(file_name, true) if private_changed
end

def change_api_layer(file_name, new_value)
  text = File.read(file_name)
  pattern = new_value ? /API_LAYER: false/ : /API_LAYER: true/
  if (new_value && text =~ /API_LAYER: true/) || (new_value.is_a?(FalseClass) && text =~ /API_LAYER: false/)
    new_value ? puts('API Layer already switched ON') : puts('API Layer already switched OFF')
    puts text
    return false
  else
    new_contents = text.gsub(pattern, "API_LAYER: #{new_value}")
    # To merely print the contents of the file, use:
    puts new_contents
    # To write changes to the file, use:
    File.open(file_name, 'w') { |file| file.puts new_contents }
    return true
  end
end

def change_private_api_layer(file_name, new_value)
  text = File.read(file_name)
  pattern = new_value ? /PRIVATE_API: false/ : /PRIVATE_API: true/
  if (new_value && text =~ /PRIVATE_API: true/) || (new_value.is_a?(FalseClass) && text =~ /PRIVATE_API: false/)
    new_value ? puts('Private API Layer already switched ON') : puts('Private API Layer already switched OFF')
    return true
  else
    new_contents = text.gsub(pattern, "PRIVATE_API: #{new_value}")
    File.open(file_name, 'w') { |file| file.puts new_contents }
    return false
  end
end

load_environment(file_name)
require File.expand_path('../../../test/api/helpers/mock_test_validation', __FILE__)
require 'rails/test_help'
require 'minitest/rails'
require 'minitest/reporters'
require 'json_expressions/minitest'
include ActiveSupport::Rescuable

Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new, Minitest::Reporters::JUnitReporter.new('test/reports')]

$env_loaded = true # To make sure we don't load the environment again
