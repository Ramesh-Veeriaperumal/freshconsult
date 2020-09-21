require_relative '../test_helper'
require_relative '../../models/helpers/freshchat_account_test_helper'
require_relative '../../models/helpers/freshcaller_account_test_helper'

class OcrToMarsApiTest < ActiveSupport::TestCase
  include AccountTestHelper
  include FreshchatAccountTestHelper
  include FreshcallerAccountTestHelper
  include Redis::OthersRedis
  include Redis::Keys::Others

  def setup
    super
    @account = create_test_account if @account.nil?
    @account.make_current
    create_freshchat_account(@account) unless @account.freshchat_account
    create_freshcaller_account(@account) unless @account.freshcaller_account
  end

  def test_feature_launch
    OcrToMarsApi.new.on_launch(@account.id)
    chat_account_ids = get_all_members_in_a_redis_set(OCR_TO_MARS_CHAT_ACCOUNT_IDS)
    caller_account_ids = get_all_members_in_a_redis_set(OCR_TO_MARS_CALLER_ACCOUNT_IDS)
    assert_equal chat_account_ids.size, 1
    assert_equal chat_account_ids.include?(@account.freshchat_account.app_id), true
    assert_equal caller_account_ids.size, 1
    assert_equal caller_account_ids.include?(@account.freshcaller_account.freshcaller_account_id.to_s), true
  end

  def test_feature_rollback
    OcrToMarsApi.new.on_launch(@account.id)
    OcrToMarsApi.new.on_rollback(@account.id)
    chat_account_ids = get_all_members_in_a_redis_set(OCR_TO_MARS_CHAT_ACCOUNT_IDS)
    caller_account_ids = get_all_members_in_a_redis_set(OCR_TO_MARS_CALLER_ACCOUNT_IDS)
    assert_equal chat_account_ids.size, 0
    assert_equal caller_account_ids.size, 0
  end
end
