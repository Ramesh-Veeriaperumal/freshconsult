require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class FreshchatAccountTest < ActiveSupport::TestCase
  include AccountTestHelper
  include FreshchatAccountTestHelper
  include Redis::OthersRedis
  include Redis::Keys::Others

  def setup
    super
    @account = create_test_account if @account.nil?
    @account.make_current
  end

  def test_ocr_to_mars_redis_on_freshchat_account_create
    @account.launch(:ocr_to_mars_api)
    prev_cnt = get_all_members_in_a_redis_set(OCR_TO_MARS_CHAT_ACCOUNT_IDS).size
    @account.freshchat_account&.destroy
    create_freshchat_account(@account)
    chat_account_ids = get_all_members_in_a_redis_set(OCR_TO_MARS_CHAT_ACCOUNT_IDS)
    assert_equal chat_account_ids.size, prev_cnt + 1
    assert_equal chat_account_ids.include?(@account.freshchat_account.app_id), true
  ensure
    @account.rollback(:ocr_to_mars_api)
  end

  def test_ocr_to_mars_redis_without_feature
    prev_cnt = get_all_members_in_a_redis_set(OCR_TO_MARS_CHAT_ACCOUNT_IDS).size
    @account.freshchat_account&.destroy
    create_freshchat_account(@account)
    chat_account_ids = get_all_members_in_a_redis_set(OCR_TO_MARS_CHAT_ACCOUNT_IDS)
    assert_equal chat_account_ids.size, prev_cnt
  end

  def test_ocr_to_mars_redis_on_freshchat_account_enabled_key_update
    @account.launch(:ocr_to_mars_api)
    chat_account = @account.freshchat_account || create_freshchat_account(@account)
    chat_account_ids = get_all_members_in_a_redis_set(OCR_TO_MARS_CHAT_ACCOUNT_IDS)
    assert_equal chat_account_ids.include?(@account.freshchat_account.app_id), true
    chat_account.enabled = false
    chat_account.save!
    chat_account_ids = get_all_members_in_a_redis_set(OCR_TO_MARS_CHAT_ACCOUNT_IDS)
    assert_equal chat_account_ids.include?(@account.freshchat_account.app_id), false
  ensure
    @account.rollback(:ocr_to_mars_api)
  end

  def test_ocr_to_mars_redis_on_freshchat_account_destroy
    @account.launch(:ocr_to_mars_api)
    chat_account = @account.freshchat_account || create_freshchat_account(@account)
    chat_account_ids = get_all_members_in_a_redis_set(OCR_TO_MARS_CHAT_ACCOUNT_IDS)
    assert_equal chat_account_ids.include?(@account.freshchat_account.app_id), true
    chat_account.destroy
    chat_account_ids = get_all_members_in_a_redis_set(OCR_TO_MARS_CHAT_ACCOUNT_IDS)
    assert_equal chat_account_ids.include?(@account.freshchat_account.app_id), false
  ensure
    @account.rollback(:ocr_to_mars_api)
  end
end
