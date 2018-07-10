require_relative '../unit_test_helper'

class CompanySegmentFilterDataTest < ActionView::TestCase

  VALID_FILTER_DATA = [{"condition"=>"created_at", "operator"=>"is_greater_than", "type"=>"default", "value"=>"month"}]
  INVALID_FILTER_DATA = [{"condition"=>"createdat", "operator"=>"is_greater_than", "type"=>"default", "value"=>"month"}]

  def test_data_absence
    account = Account.first.make_current
    cf = account.company_filters.new(:name => Faker::Name.name, :data => nil)
    refute cf.valid?
    errors = cf.errors.full_messages
    assert errors.include?("Data can't be blank")
  ensure
    Account.reset_current_account
  end

  def test_invalid_data
    account = Account.first.make_current
    cf = account.company_filters.new(:name => Faker::Name.name, :data => INVALID_FILTER_DATA)
    refute cf.valid?
    errors = cf.errors.full_messages
    assert errors.include?("Data Invalid Query Hash")
  ensure
    Account.reset_current_account
  end

  def test_valid_data
    account = Account.first.make_current
    cf = account.company_filters.new(:name => Faker::Name.name, :data => VALID_FILTER_DATA)
    assert cf.valid?
  ensure
    Account.reset_current_account
  end
end
