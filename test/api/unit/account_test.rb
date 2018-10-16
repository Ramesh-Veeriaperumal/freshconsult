require_relative '../unit_test_helper'

class AccountTest < ActionView::TestCase
  def test_domain_valid
    account = Account.new(domain: "test-1234", name: "Test Account")
    account.time_zone = "Chennai"
    plan = SubscriptionPlan.find_by_name "Sprout"
    account.plan = plan
    assert account.valid?
  end

  def test_domain_start_with_hyphen_invalid
    account = Account.new(domain: "-test1234")
    refute account.valid?
    errors = account.errors.full_messages
    assert errors.include?('Domain is invalid')
  end

  def test_domain_end_with_hyphen_invalid
    account = Account.new(domain: "test1234-")
    refute account.valid?
    errors = account.errors.full_messages
    assert errors.include?('Domain is invalid')
  end

  def test_domain_with_special_characters_invalid
    account = Account.new(domain: "test*1234")
    refute account.valid?
    errors = account.errors.full_messages
    assert errors.include?('Domain is invalid')
  end
end
