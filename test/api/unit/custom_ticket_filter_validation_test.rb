require_relative '../unit_test_helper'
require_relative '../helpers/ticket_fields_test_helper'

class CustomTicketFilterValidationTest < ActionView::TestCase

  include TicketFieldsTestHelper

  def tear_down
    Account.unstub(:current)
    super
  end

  def stub_account
    Account.stubs(:current).returns(Account.first)
  end

  def sample_params
    {
      name: Faker::Name.name,
      order: ApiTicketConstants::ORDER_BY.sample,
      order_type: ApiTicketConstants::ORDER_TYPE.sample,
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
        group_id: (Account.current.groups.first || {})[:id] || 1
      },
    }
  end

  def test_missing_attributes
    stub_account
    (sample_params.keys - [:per_page]).each do |attribute|
      filter = CustomTicketFilterValidation.new(sample_params.except(attribute))
      refute filter.valid?
    end
  end

  def test_invalid_attributes
    stub_account
    filter = CustomTicketFilterValidation.new({})
    refute filter.valid?
    error = filter.errors.full_messages
    assert error.include?("Name missing_field")
    assert error.include?("Order missing_field")
    assert error.include?("Order type missing_field")
    assert error.include?("Query hash missing_field")
    assert error.include?("Visibility missing_field")
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
    assert error.include?("Name datatype_mismatch")
    assert error.include?("Query hash datatype_mismatch")
    assert error.include?("Visibility datatype_mismatch")
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
    filter_params[:order] = 'random_order'
    filter_params[:order_type] = 'random_type'
    filter = CustomTicketFilterValidation.new(filter_params)
    refute filter.valid?
    error = filter.errors.full_messages
    assert error.include?("Query hash invalid_query_conditions")
    assert error.include?("Visibility not_included")
    assert error.include?("Order type not_included")
    assert error.include?("Order not_included")
  end

  def test_invalid_group
    stub_account
    filter_params = sample_params
    filter_params[:visibility][:visibility] = Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents]
    filter_params[:visibility][:group_id] = 0
    filter = CustomTicketFilterValidation.new(filter_params)
    refute filter.valid?
    error = filter.errors.full_messages
    assert error.include?("Group invalid_group_id")
  end

  def test_valid_filter_params
    stub_account
    filter = CustomTicketFilterValidation.new(sample_params)
    assert filter.valid?
  end

end
