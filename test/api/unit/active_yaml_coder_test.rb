require_relative '../unit_test_helper'

class ActiveYAMLCoderTest < ActiveSupport::TestCase
  def test_nested_hash_with_child_action_controller_parameters_hash
    object = { a:  { b: { c: ActionController::Parameters.new(d: 1) } } }
    yaml_object = ActiveRecord::Coders::YAMLColumn.new(Hash).dump(object)
    assert_equal Syck.load(yaml_object), Psych.load(yaml_object)
  end

  def test_nested_hash_action_controller_parameters
    object = ActionController::Parameters.new(a:  ActionController::Parameters.new(b: ActionController::Parameters.new(c: ActionController::Parameters.new(d: 1))))
    yaml_object = ActiveRecord::Coders::YAMLColumn.new(Hash).dump(object)
    assert_equal Syck.load(yaml_object), Psych.load(yaml_object)
  end

  def test_nested_hash_action_controller_parameters_with_child_array_action_controller_parameters_hash
    object = ActionController::Parameters.new(a:  ActionController::Parameters.new(b: [ActionController::Parameters.new(c: ActionController::Parameters.new(d: 1))]))
    yaml_object = ActiveRecord::Coders::YAMLColumn.new(Hash).dump(object)
    assert_equal Syck.load(yaml_object), Psych.load(yaml_object)
  end

  def test_nested_hash_with_array_child_action_controller_parameters_hash
    object = { a:  { b: [c: ActionController::Parameters.new(d: 1)] } }
    yaml_object = ActiveRecord::Coders::YAMLColumn.new(Hash).dump(object)
    assert_equal Syck.load(yaml_object), Psych.load(yaml_object)
  end

  def test_nested_hash_with_deep_child_action_controller_parameters_hash
    object = { a:  { b: [c: ActionController::Parameters.new(d: [{e: ActionController::Parameters.new(f: "test")}])] } }
    yaml_object = ActiveRecord::Coders::YAMLColumn.new(Hash).dump(object)
    assert_equal Syck.load(yaml_object), Psych.load(yaml_object)
  end

  def test_array_nested_hash_with_child_action_controller_parameters_hash
    object = [{ a:  { b: {c: ActionController::Parameters.new(d: 1)} } }]
    yaml_object = ActiveRecord::Coders::YAMLColumn.new(Array).dump(object)
    assert_equal Syck.load(yaml_object), Psych.load(yaml_object)
  end

  def test_array_nested_hash_action_controller_parameters
    object = [ActionController::Parameters.new(a:  ActionController::Parameters.new(b: ActionController::Parameters.new(c: ActionController::Parameters.new(d: 1))))]
    yaml_object = ActiveRecord::Coders::YAMLColumn.new(Array).dump(object)
    assert_equal Syck.load(yaml_object), Psych.load(yaml_object)
  end

  def test_array_nested_hash_action_controller_parameters_with_child_array_action_controller_parameters_hash
    object = [ActionController::Parameters.new(a:  ActionController::Parameters.new(b: [ActionController::Parameters.new(c: ActionController::Parameters.new(d: 1))]))]
    yaml_object = ActiveRecord::Coders::YAMLColumn.new(Array).dump(object)
    assert_equal Syck.load(yaml_object), Psych.load(yaml_object)
  end

  def test_array_nested_hash_with_child_array_action_controller_parameters_hash
    object = [{ a:  { b: [c: ActionController::Parameters.new(d: 1)] } }]
    yaml_object = ActiveRecord::Coders::YAMLColumn.new(Array).dump(object)
    assert_equal Syck.load(yaml_object), Psych.load(yaml_object)
  end

  def test_array_nested_hash_with_deep_child_action_controller_parameters_hash
    object = [{ a:  { b: [c: ActionController::Parameters.new(d: [{e: ActionController::Parameters.new(f: "test")}])] } }]
    yaml_object = ActiveRecord::Coders::YAMLColumn.new(Array).dump(object)
    assert_equal Syck.load(yaml_object), Psych.load(yaml_object)
  end

end
