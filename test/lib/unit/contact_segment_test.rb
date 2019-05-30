require_relative '../test_helper'
require 'minitest/spec'
['contact_segments_test_helper.rb', 'company_helper.rb'].each { |file| require Rails.root.join("test/lib/helpers/#{file}") }

class ContactSegmentTest < ActiveSupport::TestCase
  include ContactSegmentsTestHelper
  include ApiCompanyHelper

  def setup
    super
    before_all
  end

  def teardown
    super
    User.reset_current_user
  end

  def before_all
    @agent.make_current
  end

  def test_contact_segment_with_tag_names_is_in_valid
    input_params = [{ name: 'tag_names', value: ['test1'], operator: 'is_in'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(tag_names: ['test1', 'test2'].join(','))
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_tag_names_is_in_invalid
    input_params = [{ name: 'tag_names', value: ['test3'], operator: 'is_in'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(tag_names: ['test1', 'test2'].join(','))
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_company_name_is_in_valid
    company1 = create_company
    input_params = [{ name: 'company_name', value: [company1.id], operator: 'is_in'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(company_ids: [company1.id])
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_company_name_and_multiple_user_companies_is_in_valid
    company1 = create_company
    input_params = [{ name: 'company_name', value: [company1.id], operator: 'is_in'}]
    segment, fields = create_segment(input_params)
    company2 = create_company
    contact = create_contact(company_ids: [company1.id, company2.id])
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_company_name_is_in_invalid
    company1 = create_company
    input_params = [{ name: 'company_name', value: [company1.id], operator: 'is_in'}]
    segment, fields = create_segment(input_params)
    company2 = create_company
    contact = create_contact(company_ids: [company2.id])
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_company_name_and_contact_no_company_is_in_invalid
    company1 = create_company
    input_params = [{ name: 'company_name', value: [company1.id], operator: 'is_in'}]
    segment, fields = create_segment(input_params)
    #company2 = create_company
    contact = create_contact(company_ids: [])
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_time_zone_is_in_valid
    input_params = [{ name: 'time_zone', value: ['Chennai'], operator: 'is_in'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(time_zone: 'Chennai')
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_time_zone_is_in_invalid
    input_params = [{ name: 'time_zone', value: ['Chennai'], operator: 'is_in'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(time_zone: 'Karachi')
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_greater_than_valid
    input_params = [{ name: 'created_at', value: { after: 10.days.ago.to_s }, operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: Faker::Time.between(9.days.ago, Date.today).to_time)
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_greater_than_invalid
    input_params = [{ name: 'created_at', value: { after: 10.days.ago.to_s }, operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: Faker::Time.between(20.days.ago, 11.days.ago))
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_greater_than_invalid_exclusive
    input_params = [{ name: 'created_at', value: { after: 10.days.ago.to_s }, operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: 10.days.ago)
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_less_than_valid
    input_params = [{ name: 'created_at', value: { before: 10.days.ago.to_s }, operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: Faker::Time.between(20.days.ago, 11.days.ago))
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_less_than_invalid
    input_params = [{ name: 'created_at', value: { before: 10.days.ago.to_s }, operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: Faker::Time.between(9.days.ago, Date.today))
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_less_than_invalid_exclusive
    input_params = [{ name: 'created_at', value: { before: 10.days.ago.to_s }, operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: 10.days.ago)
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_between_valid
    input_params = [{ name: 'created_at', value: { from: 30.days.ago.to_s, to: 10.days.ago.to_s }, operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: Faker::Time.between(10.days.ago, 30.days.ago))
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_between_invalid_greater
    input_params = [{ name: 'created_at', value: { from: 30.days.ago.to_s, to: 10.days.ago.to_s }, operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: Faker::Time.between(40.days.ago, 50.days.ago))
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_between_invalid_lesser
    input_params = [{ name: 'created_at', value: { from: 30.days.ago.to_s, to: 20.days.ago.to_s }, operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: Faker::Time.between(10.days.ago, 1.days.ago))
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_between_valid_left_inclusive
    input_params = [{ name: 'created_at', value: { from: 30.days.ago.to_s, to: 10.days.ago.to_s }, operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: 10.days.ago)
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_between_valid_right_inclusive
    input_params = [{ name: 'created_at', value: { from: 30.days.ago.to_s, to: 10.days.ago.to_s }, operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: 30.days.ago)
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_is_today_valid
    input_params = [{ name: 'created_at', value: 'today', operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: Time.zone.now)
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_is_today_invalid
    input_params = [{ name: 'created_at', value: 'today', operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: Faker::Time.between(10.days.ago, 20.days.ago))
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_is_yesterday_valid
    input_params = [{ name: 'created_at', value: 'yesterday', operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: 1.day.ago)
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_is_yesterday_invalid
    input_params = [{ name: 'created_at', value: 'yesterday', operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: Faker::Time.between(10.days.ago, 20.days.ago))
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_is_last_week_valid
    input_params = [{ name: 'created_at', value: 'last_week', operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: Faker::Time.between(6.days.ago, Date.today))
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_is_last_week_invalid
    input_params = [{ name: 'created_at', value: 'last_week', operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: Faker::Time.between(10.days.ago, 20.days.ago))
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_is_last_week_invalid_exclusive
    input_params = [{ name: 'created_at', value: 'last_week', operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: 7.days.ago)
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_is_last_month_valid
    input_params = [{ name: 'created_at', value: 'last_month', operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: Faker::Time.between(29.days.ago, Date.today))
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_is_last_month_invalid
    input_params = [{ name: 'created_at', value: 'last_month', operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: Faker::Time.between(40.days.ago, 60.days.ago))
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_created_at_is_last_month_invalid_exclusive
    input_params = [{ name: 'created_at', value: 'last_month', operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact = create_contact(created_at: 30.days.ago)
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_number_greater_than_valid
    input_params = [{ name: 'custom_number', value: "20", operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact_hash = { custom_fields: { fields.first.name.to_sym => Faker::Number.between(21, 100) } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_number_greater_than_invalid
    input_params = [{ name: 'custom_number', value: "20", operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact_hash = { custom_fields: { fields.first.name.to_sym => Faker::Number.between(0, 20) } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_number_greater_than_invalid_exclusive
    input_params = [{ name: 'custom_number', value: "20", operator: 'is_greater_than'}]
    segment, fields = create_segment(input_params)
    contact_hash = { custom_fields: { fields.first.name.to_sym => 20 } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_number_less_than_valid
    input_params = [{ name: 'custom_number', value: "20", operator: 'is_less_than'}]
    segment, fields = create_segment(input_params)
    contact_hash = { custom_fields: { fields.first.name.to_sym => Faker::Number.between(0, 19) } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_number_less_than_invalid
    input_params = [{ name: 'custom_number', value: "20", operator: 'is_less_than'}]
    segment, fields = create_segment(input_params)
    contact_hash = { custom_fields: { fields.first.name.to_sym => Faker::Number.between(20, 100) } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_number_less_than_invalid_exclusive
    input_params = [{ name: 'custom_number', value: "20", operator: 'is_less_than'}]
    segment, fields = create_segment(input_params)
    contact_hash = { custom_fields: { fields.first.name.to_sym => 20 } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_number_between_valid
    input_params = [{ name: 'custom_number', value: { from: 10, to: 30 }, operator: 'is_between'}]
    segment, fields = create_segment(input_params)
    contact_hash = { custom_fields: { fields.first.name.to_sym => 20 } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_number_between_invalid_greater
    input_params = [{ name: 'custom_number', value: { from: 10, to: 30 }, operator: 'is_between'}]
    segment, fields = create_segment(input_params)
    contact_hash = { custom_fields: { fields.first.name.to_sym => 40 } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_number_between_invalid_lesser
    input_params = [{ name: 'custom_number', value: { from: 10, to: 30 }, operator: 'is_between'}]
    segment, fields = create_segment(input_params)
    contact_hash = { custom_fields: { fields.first.name.to_sym => 5 } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_number_between_valid_left_inclusive
    input_params = [{ name: 'custom_number', value: { from: 10, to: 30 }, operator: 'is_between'}]
    segment, fields = create_segment(input_params)
    contact_hash = { custom_fields: { fields.first.name.to_sym => 10 } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_number_between_valid_right_inclusive
    input_params = [{ name: 'custom_number', value: { from: 10, to: 30 }, operator: 'is_between'}]
    segment, fields = create_segment(input_params)
    contact_hash = { custom_fields: { fields.first.name.to_sym => 30 } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_number_is_in_valid
    input_params = [{ name: 'custom_number', value: "20", operator: 'is_in'}]
    segment, fields = create_segment(input_params)
    contact_hash = { custom_fields: { fields.first.name.to_sym => 20 } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_number_is_in_invalid
    input_params = [{ name: 'custom_number', value: "20", operator: 'is_in'}]
    segment, fields = create_segment(input_params)
    contact_hash = { custom_fields: { fields.first.name.to_sym => 40 } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_checkbox_is_in_valid_true
    input_params = [{ name: 'custom_checkbox', value: "1", operator: 'is_in'}]
    segment, fields = create_segment(input_params)
    contact_hash = { custom_fields: { fields.first.name.to_sym => true } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_checkbox_is_in_valid_false
    input_params = [{ name: 'custom_checkbox', value: "0", operator: 'is_in'}]
    segment, fields = create_segment(input_params)
    contact_hash = { custom_fields: { fields.first.name.to_sym => false } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_checkbox_is_in_invalid
    input_params = [{ name: 'custom_checkbox', value: "0", operator: 'is_in'}]
    segment, fields = create_segment(input_params)
    contact_hash = { custom_fields: { fields.first.name.to_sym => true } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_dropdown_is_in_valid
    choices = Faker::Lorem.words(10)
    input_params = [{ name: 'custom_dropdown', value: choices, operator: 'is_in', options: {choices: choices} } ]
    segment, fields = create_segment(input_params)
    dropdown_value = choices[Faker::Number.between(0, 9)]
    contact_hash = { custom_fields: { fields.first.name.to_sym => dropdown_value } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_custom_dropdown_is_in_invalid
    choices = Faker::Lorem.words(10)
    input_params = [{ name: 'custom_dropdown', value: choices, operator: 'is_in', options: {choices: choices} }]
    segment, fields = create_segment(input_params)
    dropdown_value = ''
    loop do
      dropdown_value = Faker::Lorem.word
      break unless choices.include?(dropdown_value)
    end
    contact_hash = { custom_fields: { fields.first.name.to_sym => dropdown_value } }
    contact = create_contact(contact_hash)
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end

  def test_contact_segment_with_missing_field
    input_params = [{ name: 'custom_dropdown', value: Faker::Lorem.word, operator: 'is_in', create_field: false }]
    segment, fields = create_segment(input_params)
    contact = create_contact({})
    segment_match = Segments::Match::Contact.new(contact)
    assert_not_includes segment_match.ids(segment_ids: [segment.id]), segment.id
  end
end
