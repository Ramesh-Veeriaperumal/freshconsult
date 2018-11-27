require_relative '../unit_test_helper'

class GroupFilterValidationTest < ActionView::TestCase

	def teardown
    super
    Account.unstub(:current)
  end

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end
  
  def test_valid
    group_filter = GroupFilterValidation.new(group_type: @account.group_types.first.name)
    assert group_filter.valid?
  end

  def test_invalid
    group_filter = GroupFilterValidation.new(group_type: nil)
    refute group_filter.valid?
  end

end
