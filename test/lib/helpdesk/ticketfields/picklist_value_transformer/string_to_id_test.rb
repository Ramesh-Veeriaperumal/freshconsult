require_relative '../../../test_helper'
['ticket_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

class StringToIdTest < ActionView::TestCase
  include TicketFieldsTestHelper

  def setup
    super
    @account.make_current
    @dropdown_field = create_custom_field_dropdown("cf_#{Faker::Name.name}", Faker::Lorem.words(5).uniq.freeze)
    @picklist_values = @dropdown_field.picklist_values
    @picklist_value_mapping_by_id = @picklist_values.each_with_object({}) { |pv, map| map[pv.picklist_id] = pv.value }
    @picklist_value_mapping_by_value = @picklist_values.each_with_object({}) { |pv, map| map[pv.value] = pv.picklist_id }
    @transformer = Helpdesk::Ticketfields::PicklistValueTransformer::StringToId.new
  end

  def teardown
    super
  end

  def test_fetch_ids_with_valid_option
    picklist_value = @picklist_values.first
    response = @transformer.fetch_ids(Array.wrap(picklist_value.value), @dropdown_field.name)
    assert_equal [picklist_value.picklist_id], response
  end

  def test_fetch_ids_with_invalid_option
    random_value = get_random_value
    response = @transformer.fetch_ids(Array.wrap(random_value), @dropdown_field.name)
    assert_equal [nil], response
  end

  def test_fetch_ids_with_a_valid_and_invalid_option
    picklist_value = @picklist_values.first
    random_value = get_random_value
    response = @transformer.fetch_ids([picklist_value.value, random_value], @dropdown_field.name)
    assert_equal [picklist_value.picklist_id, nil], response
  end

  def test_fetch_ids_with_a_valid_and_none_option
    picklist_value = @picklist_values.first
    response = @transformer.fetch_ids([picklist_value.value, '-1'], @dropdown_field.name)
    assert_equal [picklist_value.picklist_id, '-1'], response
  end

  def get_random_value
    random_value = ''
    loop do
      random_value = Faker::Name.name
      break unless @picklist_value_mapping_by_value.key?(random_value)
    end
    random_value
  end
end
