require_relative '../../test_helper'

class NestedDropdownTest < ActiveSupport::TestCase
  def nested_choices_params
    [{ value: "A#{Faker::Lorem.characters(10)}", choices: [value: "A#{Faker::Lorem.characters(10)}"] }, { value: "A#{Faker::Lorem.characters(10)}", choices: [value: "A#{Faker::Lorem.characters(10)}"] }, { value: "A#{Faker::Lorem.characters(10)}", choices: [value: "A#{Faker::Lorem.characters(10)}"] }]
  end

  def test_building_new_choices
    choice_params = nested_choices_params
    ticket_field = Account.first.ticket_fields.new
    Builder::Choices::NestedField.new(ticket_field).build_new_choices(choice_params)
    ticket_field.picklist_values.each_with_index do |picklist_value, index|
      assert_equal picklist_value.value, choice_params[index][:value]
      assert_equal picklist_value.position, index + 1
      level_1_check(picklist_value.sub_picklist_values, choice_params[index][:choices])
    end
  end

  def level_1_check(sub_picklist_values, choices_params)
    sub_picklist_values.each_with_index do |picklist_value, index|
      assert_equal picklist_value.value, choices_params[index][:value]
      assert_equal picklist_value.position, index + 1
    end
  end
end
