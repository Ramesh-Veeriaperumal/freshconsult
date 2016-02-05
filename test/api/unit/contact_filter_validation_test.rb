require_relative '../unit_test_helper'

class ContactFilterValidationTest < ActionView::TestCase
  
  def tear_down
    Account.unstub(:current)
    Account.any_instance.unstub(:companies)
    ActiveRecord::Relation.any_instance.unstub(find_by_id)
    super
  end

  def test_valid
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:companies).returns(Company.scoped)
    ActiveRecord::Relation.any_instance.stubs(:find_by_id).returns(true)
    contact_filter = ContactFilterValidation.new(state: 'blocked', email: Faker::Internet.email, 
                                    phone: Faker::PhoneNumber.phone_number, 
                                    mobile: Faker::PhoneNumber.phone_number, company_id: 1)
    assert contact_filter.valid?
  end

  def test_invalid_state 
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:companies).returns(Company.all)
    ActiveRecord::Relation.any_instance.stubs(:find_by_id).returns(true)
    contact_filter = ContactFilterValidation.new(state: 'all')
    refute contact_filter.valid?
    error = contact_filter.errors.full_messages
    assert error.include?('State not_included')
  end

   def test_nil
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:companies).returns(Company.scoped)
    ActiveRecord::Relation.any_instance.stubs(:find_by_id).returns(true)
    contact_filter = ContactFilterValidation.new(state: nil, email: nil, 
                                    phone: nil, mobile: nil, company_id: nil)
    refute contact_filter.valid?
    error = contact_filter.errors.full_messages
    assert error.include?('State not_included')
    assert error.include?('Email not_a_valid_email')
    assert error.include?('Phone data_type_mismatch')
    assert error.include?('Mobile data_type_mismatch')
    assert error.include?('Company data_type_mismatch')
  end
end
