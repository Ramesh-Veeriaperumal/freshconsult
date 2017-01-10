require_relative '../unit_test_helper'

class TicketFilterValidationTest < ActionView::TestCase
  def tear_down
    Account.unstub(:current)
    Account.any_instance.unstub(:companies)
    ActiveRecord::Relation.any_instance.unstub(find_by_id)
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
      order_by: { list: 'due_by,created_at,updated_at,status' },
      order_type: { list: 'asc,desc' } }, ticket_filter.error_options)
  end
end
