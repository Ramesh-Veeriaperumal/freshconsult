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

  def test_modify_data_hash_with_feature_enabled
    transformer = Helpdesk::Ticketfields::PicklistValueTransformer::StringToId.new
    Account.current.launch(:wf_comma_filter_fix)
    names = Faker::Lorem.words(3).map { |x| "nf_stoid_one_#{x}" }
    nested_value_level_1 = Faker::Lorem.word
    nested_value_level_1_1 = Faker::Lorem.word
    nested_value_level_1_2 = Faker::Lorem.word
    nested_value_level_1_1_1 = Faker::Lorem.word
    nested_value_level_1_2_1 = Faker::Lorem.word

    nested_values =  [[nested_value_level_1, '0',
                      [[nested_value_level_1_1, '0', [[nested_value_level_1_1_1, 0]]],
                        [nested_value_level_1_2, '0', [[nested_value_level_1_2_1, 0]]]]]]

    nested_field_level_1 = create_dependent_custom_field(names, Random.rand(60..70), nil, nil, nested_values)
    Account.find(Account.current.id).make_current
    nested_field_level_2 = nested_field_level_1.nested_ticket_fields.where(level: 2).first.flexifield_def_entry.ticket_field
    nested_field_level_3 = nested_field_level_1.nested_ticket_fields.where(level: 3).first.flexifield_def_entry.ticket_field

    nested_field_level_1_value = nested_field_level_1.picklist_values.where(value: nested_value_level_1).first
    nested_field_level_2_value = nested_field_level_1_value.sub_picklist_values.where(value: nested_value_level_1_1).first
    nested_field_level_3_value = nested_field_level_2_value.sub_picklist_values.where(value: nested_value_level_1_1_1).first
    data_hash = [
      { "condition" => "flexifields.#{nested_field_level_1.flexifield_def_entry.flexifield_name}", "operator"=>"is_in", "value"=> [nested_field_level_1_value.value], "ff_name"=>"#{nested_field_level_1.name}" },
      { "condition" => "flexifields.#{nested_field_level_2.flexifield_def_entry.flexifield_name}", "operator"=>"is_in", "value"=> [nested_field_level_2_value.value], "ff_name"=>"#{nested_field_level_2.name}" },
      { "condition" => "flexifields.#{nested_field_level_3.flexifield_def_entry.flexifield_name}", "operator"=>"is_in", "value"=> [nested_field_level_3_value.value], "ff_name"=>"#{nested_field_level_3.name}" }
    ]

    result = transformer.modify_data_hash(data_hash)
    assert result[0]["value"].to_i.is_a?(Integer)
    assert result[1]["value"].to_i.is_a?(Integer)
    assert result[2]["value"].to_i.is_a?(Integer)
   ensure
    Account.current.rollback(:wf_comma_filter_fix)
  end

  def test_modify_data_hash_without_feature_enabled
    transformer = Helpdesk::Ticketfields::PicklistValueTransformer::StringToId.new
    Account.current.rollback(:wf_comma_filter_fix)
    names = Faker::Lorem.words(3).map { |x| "nf_stoid_two_#{x}" }
    nested_value_level_1 = Faker::Lorem.word
    nested_value_level_1_1 = Faker::Lorem.word
    nested_value_level_1_2 = Faker::Lorem.word
    nested_value_level_1_1_1 = Faker::Lorem.word
    nested_value_level_1_2_1 = Faker::Lorem.word

    nested_values =  [[nested_value_level_1, '0',
                      [[nested_value_level_1_1, '0', [[nested_value_level_1_1_1, 0]]],
                        [nested_value_level_1_2, '0', [[nested_value_level_1_2_1, 0]]]]]]

    nested_field_level_1 = create_dependent_custom_field(names, Random.rand(40..50), nil, nil, nested_values)
    Account.find(Account.current.id).make_current
    nested_field_level_2 = nested_field_level_1.nested_ticket_fields.where(level: 2).first.flexifield_def_entry.ticket_field
    nested_field_level_3 = nested_field_level_1.nested_ticket_fields.where(level: 3).first.flexifield_def_entry.ticket_field

    nested_field_level_1_value = nested_field_level_1.picklist_values.where(value: nested_value_level_1).first
    nested_field_level_2_value = nested_field_level_1_value.sub_picklist_values.where(value: nested_value_level_1_1).first
    nested_field_level_3_value = nested_field_level_2_value.sub_picklist_values.where(value: nested_value_level_1_1_1).first
    data_hash = [
      { "condition" => "flexifields.#{nested_field_level_1.flexifield_def_entry.flexifield_name}", "operator"=>"is_in", "value"=> "#{nested_field_level_1_value.value}", "ff_name"=>"#{nested_field_level_1.name}" },
      { "condition" => "flexifields.#{nested_field_level_2.flexifield_def_entry.flexifield_name}", "operator"=>"is_in", "value"=> "#{nested_field_level_2_value.value}", "ff_name"=>"#{nested_field_level_2.name}" },
      { "condition" => "flexifields.#{nested_field_level_3.flexifield_def_entry.flexifield_name}", "operator"=>"is_in", "value"=> "#{nested_field_level_3_value.value}", "ff_name"=>"#{nested_field_level_3.name}" }
    ]

    result = transformer.modify_data_hash(data_hash)
    assert result[0]["value"].to_i.is_a?(Integer)
    assert result[1]["value"].to_i.is_a?(Integer)
    assert result[2]["value"].to_i.is_a?(Integer)
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
