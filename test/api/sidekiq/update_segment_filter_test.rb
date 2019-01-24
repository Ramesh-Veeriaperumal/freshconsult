require_relative '../unit_test_helper'
require_relative '../../lib/helpers/contact_segments_test_helper.rb'
require_relative '../../lib/helpers/company_segments_test_helper.rb'

require 'sidekiq/testing'

class UpdateSegmentFilterTest < ActionView::TestCase
  class ContactSegmentFilter
    include ContactSegmentsTestHelper

    def create_segment(field_params)
      super
    end
  end

  class CompanySegmentFilter
    include CompanySegmentsTestHelper

    def create_segment(field_params)
      super
    end
  end

  CONTACT = 'Contact'.freeze
  COMPANY = 'Company'.freeze

  def setup
    @account = Account.first || create_new_account
    @account.make_current
    @segment_filters = {}.tap do |filter_hash|
      filter_hash[CONTACT] = ContactSegmentFilter.new
      filter_hash[COMPANY] = CompanySegmentFilter.new
    end
  end

  def test_fields_update_for_contact_fields
    assert_on_invalid_segment_data(CONTACT)
  end

  def test_fields_update_for_deleted_contact_field
    refute_on_deleted_field_presence(CONTACT)
  end

  def test_fields_update_for_company_fields
    assert_on_invalid_segment_data(COMPANY)
  end

  def test_fields_update_for_deleted_company_field
    refute_on_deleted_field_presence(COMPANY)
  end

  def refute_on_deleted_field_presence(type)
    segment, fields = @segment_filters[type].create_segment(field_params(2))
    field_to_delete = fields.first
    deleted_field_name = field_to_delete.name.sub(/cf_/, '')
    field_to_delete.destroy
    UpdateSegmentFilter.new.fields_update(get_field_params(type))
    refute segment.reload.data.any? { |filter| filter['condition'] == deleted_field_name }
  end

  def assert_on_invalid_segment_data(type)
    segment, fields = @segment_filters[type].create_segment(field_params(2))
    filter_data_before_change = segment.data.dup
    UpdateSegmentFilter.new.fields_update(get_field_params(type))
    assert segment.reload.data == filter_data_before_change
  end

  def construct_field_params
    choices = Faker::Lorem.words(10)
    {
      name: 'custom_dropdown',
      value: choices,
      operator: 'is_in',
      options: {
        choices: choices
      }
    }
  end

  def field_params(count)
    (1..count).collect { construct_field_params }
  end

  def get_field_params(type)
    {}.tap do |params|
      params['custom_field'] = "#{type}Field"
      params['type'] = type
    end
  end
end
