require_relative '../test_helper'
require_relative '../../models/helpers/freshcaller_account_test_helper'

class AgentStatusTest < ActiveSupport::TestCase
  include AccountTestHelper
  include FreshcallerAccountTestHelper
  include Redis::OthersRedis
  include Redis::Keys::Others

  def setup
    super
    @account = create_test_account if @account.nil?
    @account.make_current
    create_freshcaller_account(@account) unless @account.freshcaller_account
  end

  def test_feature_launch
    AgentStatus.new.on_launch(@account.id)
    caller_account_ids = get_all_members_in_a_redis_set(AGENT_STATUSES_CALLER_ACCOUNT_IDS)
    assert_equal caller_account_ids.size, 1
    assert_equal caller_account_ids.include?(@account.freshcaller_account.freshcaller_account_id.to_s), true
  end

  def test_feature_rollback
    AgentStatus.new.on_launch(@account.id)
    AgentStatus.new.on_rollback(@account.id)
    caller_account_ids = get_all_members_in_a_redis_set(AGENT_STATUSES_CALLER_ACCOUNT_IDS)
    assert_equal caller_account_ids.size, 0
  end
end
