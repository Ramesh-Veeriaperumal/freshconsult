require_relative '../unit_test_helper'

class SafeYamlTest < ActionView::TestCase
  def test_yaml_load_safely
    yaml_content = YAML.load("--- !ruby/object:ERB\n  src: test", safe: true)
    assert_nil yaml_content.instance_variable_get(:@src)
  end

  def test_yaml_load_unsafely
    yaml_content = YAML.load("--- !ruby/object:ERB\n  src: test")
    assert yaml_content.instance_variable_get(:@src), "test"
  end

  def test_yaml_with_valid_content
    yaml_content = YAML.load("--- privileges:\n reply_ticket: 1", safe: true)
    assert yaml_content["privileges"]["reply_ticket"], "1"
  end

  def test_yaml_with_symbols_and_without_deserialize_symbols_option
    yaml_content = YAML.load("--- :privileges:\n reply_ticket: 1", safe: true)
    assert yaml_content[:privileges]["reply_ticket"], "1"
  end

  def test_yaml_with_symbols_and_deserialize_symbols_as_false
    yaml_content = YAML.load("--- :privileges:\n reply_ticket: 1", safe: true, deserialize_symbols: false)
    assert yaml_content[":privileges"]["reply_ticket"], "1"
  end
end
