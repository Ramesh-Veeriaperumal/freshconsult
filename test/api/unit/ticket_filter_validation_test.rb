require_relative '../unit_test_helper'

class TicketFilterValidationTest < ActionView::TestCase
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
  def teardown
    Account.unstub(:current)
    Account.any_instance.unstub(:companies)
    ActiveRecord::Relation.any_instance.unstub(:find_by_id)
    Account.any_instance.unstub(:all_users)
    ActiveRecord::Relation.any_instance.unstub(:where)
    Account.any_instance.unstub(:user_emails)
    ActiveRecord::Relation.any_instance.unstub(:user_for_email)
    User.any_instance.unstub(:id)
    super
  end

  def test_valid
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:companies).returns(Company.scoped)
    Account.any_instance.stubs(:all_users).returns(User.scoped)
    Account.any_instance.stubs(:user_emails).returns(UserEmail.scoped)
    ActiveRecord::Relation.any_instance.stubs(:user_for_email).returns(User.new(id: 1))
    ActiveRecord::Relation.any_instance.stubs(:find_by_id).returns(true)
    ActiveRecord::Relation.any_instance.stubs(:where).returns([User.new])
    User.any_instance.stubs(:id).returns(1)
    ticket_filter = TicketFilterValidation.new(filter: 'new_and_my_open', 'email' => Faker::Internet.email,
                                               updated_since: Time.zone.now.iso8601, company_id: 1,
                                               order_by: 'created_at', order_type: 'asc')
    result = ticket_filter.valid?
    assert result
  end

  def test_nil_value
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:companies).returns(Company.scoped)
    Account.any_instance.stubs(:all_users).returns(User.scoped)
    Account.any_instance.stubs(:user_emails).returns(UserEmail.scoped)
    ActiveRecord::Relation.any_instance.stubs(:user_for_email).returns(User.new(id: 1))
    ActiveRecord::Relation.any_instance.stubs(:find_by_id).returns(true)
    ActiveRecord::Relation.any_instance.stubs(:where).returns([User.new])
    User.any_instance.stubs(:id).returns(1)
    ticket_filter = TicketFilterValidation.new(filter: nil, email: nil,
                                               updated_since: nil, company_id: nil,
                                               order_by: nil, order_type: nil)
    refute ticket_filter.valid?
    error = ticket_filter.errors.full_messages
    assert error.include?('Filter not_included')
    assert error.include?('Email datatype_mismatch')
    assert error.include?('Updated since invalid_date')
    assert error.include?('Company datatype_mismatch')
    assert error.include?('Order by not_included')
    assert error.include?('Order type not_included')
    assert_equal({
                   company_id: {
                     expected_data_type: :'Positive Integer', prepend_msg: :input_received,
                     given_data_type: 'Null', code: :datatype_mismatch
                   },
                   email: {
                     expected_data_type: String, prepend_msg: :input_received,
                     given_data_type: 'Null'
                   },
                   filter: { list: 'new_and_my_open,watching,spam,deleted' },
                   updated_since: { accepted: :'combined date and time ISO8601' },
                   order_by: { list: TicketsFilter.api_sort_fields_options.map(&:first).map(&:to_s).join(',') },
                   order_type: { list: 'asc,desc' }
                 }, ticket_filter.error_options)
  end

  def test_valid_case_for_private_API
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:companies).returns(Company.scoped)
    Account.any_instance.stubs(:all_users).returns(User.scoped)
    Account.any_instance.stubs(:user_emails).returns(UserEmail.scoped)
    ActiveRecord::Relation.any_instance.stubs(:user_for_email).returns(User.new(id: 1))
    ActiveRecord::Relation.any_instance.stubs(:find_by_id).returns(true)
    ActiveRecord::Relation.any_instance.stubs(:where).returns([User.new])
    User.any_instance.stubs(:id).returns(1)
    ticket_filter = TicketFilterValidation.new(filter: 'new_and_my_open', 'email' => Faker::Internet.email,
                                               updated_since: Time.zone.now.iso8601, company_id: 1,
                                               order_by: 'created_at', order_type: 'asc', version: 'private')
    assert ticket_filter.valid?
  end

  def test_invalid_filters
    Account.stubs(:current).returns(Account.new)
    ticket_filter = TicketFilterValidation.new(filter: '-5', version: 'private')
    refute ticket_filter.valid?
    errors = ticket_filter.errors.full_messages
    assert errors.include?('Filter datatype_mismatch')

    ticket_filter = TicketFilterValidation.new(filter: Faker::Lorem.word, version: 'private')
    refute ticket_filter.valid?
    errors = ticket_filter.errors.full_messages
    assert errors.include?('Filter not_included')
  end

  def test_invalid_query_hash
    Account.stubs(:current).returns(Account.new)
    ticket_filter = TicketFilterValidation.new(query_hash: nil, version: 'private')
    refute ticket_filter.valid?
    errors = ticket_filter.errors.full_messages
    assert errors.include?('Query hash datatype_mismatch')

    ticket_filter = TicketFilterValidation.new(query_hash: Faker::Lorem.word, version: 'private')
    refute ticket_filter.valid?
    errors = ticket_filter.errors.full_messages
    assert errors.include?('Query hash datatype_mismatch')
    ticket_filter = TicketFilterValidation.new(query_hash: { '0' => { 'condition' => 'responder_id' } }, version: 'private')
    refute ticket_filter.valid?
    errors = ticket_filter.errors.full_messages
    assert errors.include?('Query hash[0] operator: Mandatory attribute missing & value: Mandatory attribute missing')
  end

  def test_filter_and_query_hash_presence
    Account.stubs(:current).returns(Account.new)
    ticket_filter = TicketFilterValidation.new(filter: 2, query_hash: { 'key' => 'value' }, version: 'private')
    refute ticket_filter.valid?
    errors = ticket_filter.errors.full_messages
    assert errors.include?('Filter only_query_hash_or_filter')
  end

  def test_filtering_based_on_ids
    Account.stubs(:current).returns(Account.new)
    ticket_filter = TicketFilterValidation.new(ids: 'Invalid_id', version: 'private')
    refute ticket_filter.valid?
    errors = ticket_filter.errors.full_messages
    assert errors.include?('Ids array_datatype_mismatch')

    ticket_filter = TicketFilterValidation.new(ids: '10,20,30,40,50', version: 'private')
    assert ticket_filter.valid?
  end

  def test_empty_string_query_hash
    Account.stubs(:current).returns(Account.new)
    ticket_filter = TicketFilterValidation.new(query_hash: '', version: 'private')
    assert ticket_filter.valid?
  end

  def test_fsm_appointment_time_filter_with_valid_start_time
    Account.stubs(:current).returns(Account.first)
    Account.current.stubs(:field_service_management_enabled?).returns(true)
    perform_fsm_operations
    query_hash_params = {
      '0' => { 'condition' => 'cf_fsm_appointment_start_time', 'operator' => 'is', 'value' => { from: '2018-12-02T12:12:00', to: '2018-12-12T10:12:00' }, 'type' => 'custom_field' }
    }
    ticket_filter = TicketFilterValidation.new(query_hash: query_hash_params, version: 'private')
    assert ticket_filter.valid?
  ensure
    cleanup_fsm
    Account.any_instance.unstub(:field_service_management_enabled?)
  end

  def test_fsm_appointment_time_filter_with_valid_start_and_end_time
    Account.stubs(:current).returns(Account.first)
    Account.current.stubs(:field_service_management_enabled?).returns(true)
    perform_fsm_operations
    query_hash_params = {
      '0' => { 'condition' => 'cf_fsm_appointment_start_time', 'operator' => 'is', 'value' => { from: '2018-12-02T12:12:00', to: '2018-12-12T10:12:00' }, 'type' => 'custom_field' },
      '1' => { 'condition' => 'cf_fsm_appointment_end_time', 'operator' => 'is', 'value' => { from: '2018-12-02T12:12:00', to: '2018-12-12T10:12:00' }, 'type' => 'custom_field' }
    }
    ticket_filter = TicketFilterValidation.new(query_hash: query_hash_params, version: 'private')
    assert ticket_filter.valid?
  ensure
    cleanup_fsm
    Account.any_instance.unstub(:field_service_management_enabled?)
  end

  def test_fsm_appointment_time_filter_with_all_default_dropdown_value
    Account.stubs(:current).returns(Account.first)
    Account.current.stubs(:field_service_management_enabled?).returns(true)
    perform_fsm_operations
    failed_option = []
    TicketFilterConstants::DATE_TIME_FILTER_DEFAULT_OPTIONS.each do |value|
      query_hash_params = {
        '0' => { 'condition' => 'cf_fsm_appointment_start_time', 'operator' => 'is', 'value' => value, 'type' => 'custom_field' }
      }
      ticket_filter = TicketFilterValidation.new(query_hash: query_hash_params, version: 'private')
      failed_option << value unless ticket_filter.valid?
    end
    refute failed_option.present?
  ensure
    cleanup_fsm
    Account.any_instance.unstub(:field_service_management_enabled?)
  end

  def test_fsm_appointment_time_filter_with_invalid_start_and_end_time
    Account.stubs(:current).returns(Account.first)
    Account.current.stubs(:field_service_management_enabled?).returns(true)
    perform_fsm_operations
    query_hash_params = {
      '0' => { 'condition' => 'cf_fsm_appointment_start_time', 'operator' => 'is', 'value' => { from: '2018-12-12', to: '2018-12-02' }, 'type' => 'custom_field' }
    }
    ticket_filter = TicketFilterValidation.new(query_hash: query_hash_params, version: 'private')
    refute ticket_filter.valid?
    error = ticket_filter.errors.full_messages
    assert error.include?('Query hash[0] invalid_date_time_range')
  ensure
    cleanup_fsm
    Account.any_instance.unstub(:field_service_management_enabled?)
  end

  def test_fsm_appointment_time_filter_with_invalid_datetime_range
    Account.stubs(:current).returns(Account.first)
    Account.current.stubs(:field_service_management_enabled?).returns(true)
    perform_fsm_operations
    query_hash_params = {
      '0' => { 'condition' => 'cf_fsm_appointment_start_time', 'operator' => 'is', 'value' => { from: '2018-12-02', to: '2018-12-31' }, 'type' => 'custom_field' }
    }
    ticket_filter = TicketFilterValidation.new(query_hash: query_hash_params, version: 'private')
    refute ticket_filter.valid?
    error = ticket_filter.errors.full_messages
    assert error.include?('Query hash[0] date_limit_exceeded')
  ensure
    cleanup_fsm
    Account.any_instance.unstub(:field_service_management_enabled?)
  end

  def test_fsm_appointment_date_filter_with_invalid_string
    Account.stubs(:current).returns(Account.first)
    Account.current.stubs(:field_service_management_enabled?).returns(true)
    perform_fsm_operations
    query_hash_params = {
      '0' => { 'condition' => 'cf_fsm_appointment_start_time', 'operator' => 'is', 'value' => Faker::Lorem.characters(10), 'type' => 'custom_field' }
    }
    ticket_filter = TicketFilterValidation.new(query_hash: query_hash_params, version: 'private')
    refute ticket_filter.valid?
    error = ticket_filter.errors.full_messages
    assert error.include?('Query hash[0] query_format_invalid')
  ensure
    cleanup_fsm
    Account.any_instance.unstub(:field_service_management_enabled?)
  end
end
