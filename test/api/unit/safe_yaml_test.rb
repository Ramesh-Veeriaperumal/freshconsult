require_relative '../unit_test_helper'

class PsychSafeYamlTest < ActionView::TestCase
  def test_yaml_load_safely
    assert_raises Psych::DisallowedClass do
      yaml_content = Psych.safe_load("---\n !ruby/object:ERB\n  src: test")
    end
  end

  def test_yaml_load_unsafely
    yaml_content = Psych.load("---\n !ruby/object:ERB\n  src: test")
    assert yaml_content.instance_variable_get(:@src), "test"
  end

  def test_yaml_with_valid_content
    yaml_content = Psych.safe_load("---\nprivileges:\n reply_ticket: 1")
    assert yaml_content["privileges"]["reply_ticket"], "1"
  end

  def test_yaml_with_symbols_and_without_deserialize_symbols_option
    assert_raises Psych::DisallowedClass do
      yaml_content = Psych.safe_load("---\n:privileges:\n reply_ticket: 1")
      assert yaml_content[:privileges]["reply_ticket"], "1"
    end
  end

  def test_yaml_with_symbols_and_deserialize_symbols_as_false
    yaml_content = Psych.safe_load("---\n:privileges:\n reply_ticket: 1",[Symbol])
    assert yaml_content[:privileges]["reply_ticket"], "1"
  end

  def test_yaml_with_alias
    alias_yaml = "defaults: &defaults\n  key_pair_id: dummy\n  private_key: dummy\n  host: dummy.cloudfront.net\n\ntest:\n  <<: *defaults"
    yaml_content = Psych.safe_load(alias_yaml, [], [], true)
    assert_equal yaml_content["defaults"], yaml_content["test"]
  end
end
