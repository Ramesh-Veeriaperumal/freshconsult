ENV['RAILS_ENV'] = 'test'
file_name = File.expand_path('../../../config/infra_layer.yml', __FILE__)
require File.expand_path('../../../test/api/helpers/simple_cov_setup', __FILE__)

def load_environment(file_name)
  puts 'Switching ON API Layer'
  changed = change_api_layer(file_name, true)
  require File.expand_path('../../../config/environment', __FILE__)
  ensure
   puts 'Switching OFF API Layer'
   change_api_layer(file_name, false) if changed
end

def change_api_layer(file_name, new_value)
  text = File.read(file_name)
  pattern = new_value ? /API_LAYER: false/ : /API_LAYER: true/
  if (new_value && text =~ /API_LAYER: true/ ) || (new_value.blank? && text =~ /API_LAYER: false/)
    new_value ? puts("API Layer already switched ON") : puts("API Layer already switched OFF")
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

load_environment(file_name)
require File.expand_path('../../../test/api/helpers/mock_test_validation', __FILE__)
require 'rails/test_help'
require 'minitest/rails'
require 'minitest/reporters'
require 'json_expressions/minitest'
include ActiveSupport::Rescuable

Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new, Minitest::Reporters::JUnitReporter.new('test/api/reports')]
