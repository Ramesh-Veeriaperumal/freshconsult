require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class FreshcallerAccountTest < ActiveSupport::TestCase
  include AccountTestHelper
  include FreshcallerAccountTestHelper
  include Redis::OthersRedis
  include Redis::Keys::Others

  def setup
    super
    @account = create_test_account if @account.nil?
    @account.make_current
  end

  def test_ocr_to_mars_redis_on_freshcaller_account_create
    @account.launch(:ocr_to_mars_api)
    prev_cnt = get_all_members_in_a_redis_set(OCR_TO_MARS_CALLER_ACCOUNT_IDS).size
    @account.freshcaller_account&.destroy
    create_freshcaller_account(@account)
    check_redis_key_cnt(OCR_TO_MARS_CALLER_ACCOUNT_IDS, prev_cnt)
    check_redis_key_value(OCR_TO_MARS_CALLER_ACCOUNT_IDS, true)
  ensure
    @account.rollback(:ocr_to_mars_api)
    CentralPublishWorker::FreshcallerAccountWorker.jobs.clear
    OmniChannelDashboard::AccountWorker.jobs.clear
  end

  def test_ocr_to_mars_redis_without_feature
    prev_cnt = get_all_members_in_a_redis_set(OCR_TO_MARS_CALLER_ACCOUNT_IDS).size
    @account.freshcaller_account&.destroy
    create_freshcaller_account(@account)
    caller_account_ids = get_all_members_in_a_redis_set(OCR_TO_MARS_CALLER_ACCOUNT_IDS)
    assert_equal caller_account_ids.size, prev_cnt
  ensure
    CentralPublishWorker::FreshcallerAccountWorker.jobs.clear
    OmniChannelDashboard::AccountWorker.jobs.clear
  end

  def test_ocr_to_mars_redis_on_freshcaller_account_enabled_key_update
    @account.launch(:ocr_to_mars_api)
    caller_account = @account.freshcaller_account || create_freshcaller_account(@account)
    check_redis_key_value(OCR_TO_MARS_CALLER_ACCOUNT_IDS, true)
    caller_account.enabled = false
    caller_account.save!
    check_redis_key_value(OCR_TO_MARS_CALLER_ACCOUNT_IDS, false)
  ensure
    @account.rollback(:ocr_to_mars_api)
    CentralPublishWorker::FreshcallerAccountWorker.jobs.clear
    OmniChannelDashboard::AccountWorker.jobs.clear
  end

  def test_ocr_to_mars_redis_on_freshcaller_account_destroy
    @account.launch(:ocr_to_mars_api)
    caller_account = @account.freshcaller_account || create_freshcaller_account(@account)
    check_redis_key_value(OCR_TO_MARS_CALLER_ACCOUNT_IDS, true)
    caller_account.destroy
    check_redis_key_value(OCR_TO_MARS_CALLER_ACCOUNT_IDS, false)
  ensure
    @account.rollback(:ocr_to_mars_api)
    CentralPublishWorker::FreshcallerAccountWorker.jobs.clear
    OmniChannelDashboard::AccountWorker.jobs.clear
  end

  def test_agent_statuses_redis_on_freshcaller_account_create
    @account.launch(:agent_statuses)
    prev_cnt = get_all_members_in_a_redis_set(AGENT_STATUSES_CALLER_ACCOUNT_IDS).size
    @account.freshcaller_account&.destroy
    create_freshcaller_account(@account)
    check_redis_key_cnt(AGENT_STATUSES_CALLER_ACCOUNT_IDS, prev_cnt)
    check_redis_key_value(AGENT_STATUSES_CALLER_ACCOUNT_IDS, true)
  ensure
    @account.rollback(:agent_statuses)
    CentralPublishWorker::FreshcallerAccountWorker.jobs.clear
    OmniChannelDashboard::AccountWorker.jobs.clear
  end

  def test_agent_statuses_redis_without_feature
    prev_cnt = get_all_members_in_a_redis_set(AGENT_STATUSES_CALLER_ACCOUNT_IDS).size
    @account.freshcaller_account&.destroy
    create_freshcaller_account(@account)
    caller_account_ids = get_all_members_in_a_redis_set(OCR_TO_MARS_CALLER_ACCOUNT_IDS)
    assert_equal caller_account_ids.size, prev_cnt
  ensure
    CentralPublishWorker::FreshcallerAccountWorker.jobs.clear
    OmniChannelDashboard::AccountWorker.jobs.clear
  end

  def test_agent_statuses_redis_on_freshcaller_account_enabled_key_update
    @account.launch(:agent_statuses)
    caller_account = @account.freshcaller_account || create_freshcaller_account(@account)
    check_redis_key_value(AGENT_STATUSES_CALLER_ACCOUNT_IDS, true)
    caller_account.enabled = false
    caller_account.save!
    check_redis_key_value(AGENT_STATUSES_CALLER_ACCOUNT_IDS, false)
  ensure
    @account.rollback(:agent_statuses)
    CentralPublishWorker::FreshcallerAccountWorker.jobs.clear
    OmniChannelDashboard::AccountWorker.jobs.clear
  end

  def test_agent_statuses_redis_on_freshcaller_account_destroy
    @account.launch(:agent_statuses)
    caller_account = @account.freshcaller_account || create_freshcaller_account(@account)
    check_redis_key_value(AGENT_STATUSES_CALLER_ACCOUNT_IDS, true)
    caller_account.destroy
    check_redis_key_value(AGENT_STATUSES_CALLER_ACCOUNT_IDS, false)
  ensure
    @account.rollback(:agent_statuses)
    CentralPublishWorker::FreshcallerAccountWorker.jobs.clear
    OmniChannelDashboard::AccountWorker.jobs.clear
  end

  private

    def check_redis_key_cnt(redis_key, prev_cnt = 0)
      caller_account_ids = get_all_members_in_a_redis_set(redis_key)
      assert_equal caller_account_ids.size, prev_cnt + 1
    end

    def check_redis_key_value(redis_key, present_in_set = true)
      caller_account_ids = get_all_members_in_a_redis_set(redis_key)
      assert_equal caller_account_ids.include?(@account.freshcaller_account.freshcaller_account_id.to_s), present_in_set
    end
end
