require_relative '../unit_test_helper'
require_relative '../test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')

class AgentTypeTest < ActionView::TestCase
  include AccountHelper

  def setup
    super
    @account = Account.first || create_test_account
    Account.stubs(:current).returns(@account)
  end

  def teardown
    super
    Account.unstub(:current)
  end

  def test_agent_type_name_with_invlaid_id
    agent_type_name = AgentType.agent_type_name(-1)
    assert_equal agent_type_name, nil
  end

  def test_create_duplicate_agent_type
    AgentType.create_support_agent_type(@account)
    old_count = AgentType.count
    AgentType.create_support_agent_type(@account)
    assert_equal old_count, AgentType.count
  end

  def test_create_duplicate_agent_type_returns_agent_type
    old_agent_type = AgentType.create_support_agent_type(@account)
    old_count = AgentType.count
    new_agent_type = AgentType.create_support_agent_type(@account)
    assert_equal old_agent_type, new_agent_type
    assert_equal old_count, AgentType.count
  end
end
