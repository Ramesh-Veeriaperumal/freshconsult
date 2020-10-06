require_relative '../unit_test_helper'
require_relative '../helpers/ticket_fields_test_helper'

class CustomTicketFilterValidationTest < ActionView::TestCase
  include TicketFieldsTestHelper

  def teardown
    Account.unstub(:current)
    super
  end

  def stub_account
    Account.stubs(:current).returns(StubbedAccount.new)
  end

  def sample_params
    {
      name: Faker::Name.name,
      order_by: TicketsFilter.api_sort_fields_options.map(&:first).map(&:to_s).sample,
      order_type: ApiConstants::ORDER_TYPE.sample,
      per_page: ApiConstants::DEFAULT_PAGINATE_OPTIONS[:max_per_page],
      query_hash: [
        {
          condition: 'status',
          operator: 'is_in',
          type: 'default',
          value: [2]
        }
      ],
      visibility: {
        visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
        group_id: 1 # Just a sample value
      }
    }
  end

  def test_missing_attributes
    stub_account
    (sample_params.keys - %i[per_page visibility]).each do |attribute|
      filter = CustomTicketFilterValidation.new(sample_params.except(attribute))
      refute filter.valid?
    end
  end

  def test_invalid_attributes
    stub_account
    filter = CustomTicketFilterValidation.new({})
    refute filter.valid?(:create)
    error = filter.errors.full_messages
    assert error.include?('Name missing_field')
    assert error.include?('Order by missing_field')
    assert error.include?('Order type missing_field')
    assert error.include?('Query hash datatype_mismatch')
    assert error.include?('Group missing_field')
    assert error.include?('Visibility missing_field')
  end

  def test_invalid_datatypes
    stub_account
    filter_params = sample_params
    filter_params[:query_hash] = 'test'
    filter_params[:visibility] = 'test'
    filter_params[:name] = ['test']
    filter = CustomTicketFilterValidation.new(filter_params)
    refute filter.valid?
    error = filter.errors.full_messages
    assert error.include?('Name datatype_mismatch')
    assert error.include?('Query hash datatype_mismatch')
    assert error.include?('Visibility datatype_mismatch')
  end

  def test_invalid_values
    stub_account
    filter_params = sample_params
    filter_params[:query_hash] = [
      {
        condition: 'sample_condition'
      }
    ]
    filter_params[:visibility][:visibility] = Time.now.to_i
    filter_params[:order_by] = 'random_order'
    filter_params[:order_type] = 'random_type'
    filter = CustomTicketFilterValidation.new(filter_params)
    refute filter.valid?
    error = filter.errors.full_messages
    assert error.include?('Query hash[0] condition: is invalid & operator: Mandatory attribute missing & value: Mandatory attribute missing')
    assert error.include?('Visibility not_included')
    assert error.include?('Order type not_included')
    assert error.include?('Order by not_included')
  end

  def test_invalid_group
    stub_account
    filter_params = sample_params
    filter_params[:visibility][:visibility] = Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents]
    filter_params[:visibility][:group_id] = 0
    filter = CustomTicketFilterValidation.new(filter_params)
    refute filter.valid?
    error = filter.errors.full_messages
    assert error.include?('Group invalid_group_id')
  end

  def test_valid_filter_params
    stub_account
    filter = CustomTicketFilterValidation.new(sample_params)
    assert filter.valid?
  end

  class StubbedAccount
    def ticket_fields_from_cache
      []
    end

    def sort_by_customer_response_enabled?
      false
    end

    def sla_management_enabled?
      false
    end

    def groups_from_cache
      []
    end

    def features_included?(feature)
      false
    end

    def field_service_management_enabled?
      false
    end
  end
end
