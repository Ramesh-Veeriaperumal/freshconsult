require_relative '../unit_test_helper'
require_relative '../../../spec/support/note_helper'
class EmailHelperTest < ActiveSupport::TestCase

  include EmailHelper
  include NoteHelper

  def setup
    Account.stubs(:current).returns(Account.first || create_test_account)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_block_spam_account
    EmailHelperTest.any_instance.stubs(:ismember?).returns(false)
    EmailHelperTest.any_instance.stubs(:add_member_to_redis_set).returns(true)
    EmailHelperTest.any_instance.stubs(:get_all_members_in_a_redis_set).returns([Subscription.where("state = 'trial'").first.account_id])
    Subscription.any_instance.stubs(:active?).returns(false)
    account_id = Subscription.where("state = 'trial'").first.account_id
    remove_member_from_redis_set(SPAM_EMAIL_ACCOUNTS, account_id)
    params = {
      'account_id' => account_id,
      'type' => 'Abusive',
      'description' => 'abusive content found'
    }
    block_spam_account params
    list = get_all_members_in_a_redis_set(SPAM_EMAIL_ACCOUNTS)
    res = list.include?(account_id)
    assert_equal res, true
  end

  def test_block_spam_account_exception
    remove_member_from_redis_set(SPAM_EMAIL_ACCOUNTS, -1)
    params = {
      'account_id' => -1,
      'type' => 'Abusive',
      'description' => 'abusive content found'
    }
    block_spam_account params
    list = get_all_members_in_a_redis_set(SPAM_EMAIL_ACCOUNTS)
    res = list.include?("-1")
    assert_equal res, false
  end

  def test_parse_internal_date
    time = Time.zone.now.to_s
    parsed_date = parse_internal_date(time)
    assert_equal Time.parse(time).getutc.iso8601, parsed_date
  end

  def test_parse_internal_date_error
    parsed_date = parse_internal_date(true)
    assert_equal true, parsed_date
  end
end