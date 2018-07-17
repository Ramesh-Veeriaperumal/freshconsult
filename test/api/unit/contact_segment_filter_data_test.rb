require_relative '../unit_test_helper'

class ContactSegmentFilterDataTest < ActionView::TestCase

  VALID_FILTER_DATA = [{"condition"=>"created_at", "operator"=>"is_greater_than", "type"=>"default", "value"=>"month"}, {"condition"=>"tag_names", "operator"=>"is_in", "type"=>"default", "value"=>["apple"]}]
  INVALID_FILTER_DATA = [{"condition"=>"language", "operator"=>"is_in", "type"=>"default", "value"=>["ar", "en"]}]

  def test_data_absence
    account = Account.first.make_current
    cf = account.contact_filters.new(:name => Faker::Name.name, :data => nil)
    refute cf.valid?
    errors = cf.errors.full_messages
    assert errors.include?("Data can't be blank")
  ensure
    Account.reset_current_account
  end

  def test_invalid_data
    account = Account.first.make_current
    cf = account.contact_filters.new(:name => Faker::Name.name, :data => INVALID_FILTER_DATA)
    refute cf.valid?
    errors = cf.errors.full_messages
    assert errors.include?("Data Invalid Query Hash")
  ensure
    Account.reset_current_account
  end

  def test_valid_data
    account = Account.first.make_current
    cf = account.contact_filters.new(:name => Faker::Name.name, :data => VALID_FILTER_DATA)
    assert cf.valid?
  ensure
    Account.reset_current_account
  end
end
