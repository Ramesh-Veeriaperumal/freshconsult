require_relative '../unit_test_helper'
class EmailHelperTest < ActiveSupport::TestCase

	include EmailHelper

	def test_block_spam_account 
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

end