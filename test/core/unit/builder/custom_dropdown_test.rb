require_relative '../../test_helper'
# require_relative '../../helpers/test_files'

class CustomDropdownTest < ActiveSupport::TestCase
  def custom_dropdown_choices_params
    [{ value: "A#{Faker::Lorem.characters(10)}" }, { value: "A#{Faker::Lorem.characters(10)}" }, { value: "A#{Faker::Lorem.characters(10)}" }]
  end

  def test_building_new_choices
    choice_params = custom_dropdown_choices_params
    ticket_field = Account.first.ticket_fields.new
    Builder::Choices::CustomDropdown.new(ticket_field).build_new_choices(choice_params)
    ticket_field.picklist_values.each_with_index do |picklist_value, index|
      assert_equal picklist_value.value, choice_params[index][:value]
      assert_equal picklist_value.position, index + 1
    end
  end
end
