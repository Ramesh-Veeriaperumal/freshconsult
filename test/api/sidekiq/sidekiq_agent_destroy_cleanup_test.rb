require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
['canned_responses_helper.rb', 'group_helper.rb', 'ticket_template_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }


class SidekiqAgentDestroyCleanupTest < ActionView::TestCase

  include CoreUsersTestHelper
  include CannedResponsesHelper
  include GroupHelper
  include TicketTemplateHelper

  def teardown
    Account.unstub(:current)
    Subscription.any_instance.unstub(:switch_annual_notification_eligible?)
    super
  end

  def setup
    Account.stubs(:current).returns(Account.first)
    Subscription.any_instance.stubs(:switch_annual_notification_eligible?).returns(false)
    @account = Account.current
    @agent = add_test_agent(@account)
    @canned_response = create_response(
      title: Faker::Lorem.sentence,
      content_html: "Hi, #{Faker::Lorem.paragraph} Regards, #{Faker::Name.name}",
      visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
      user_id: @agent.id,
     )
    @user_template = create_personal_template(@agent.id)
  end

  def test_agent_destroy_valid_user
    assert_nothing_raised do
      assert_not_equal @account.canned_responses.only_me(@agent).size,0
      assert_not_equal @account.ticket_templates.only_me(@agent).size,0
      AgentDestroyCleanup.new.perform({user_id: @agent.id})
      assert_equal @account.canned_responses.only_me(@agent).size,0
      assert_equal @account.ticket_templates.only_me(@agent).size,0
    end
  end


  def test_agent_destroy_with_exception_handled
    assert_nothing_raised do
      AgentDestroyCleanup.any_instance.stubs(:destroy_agents_personal_items).raises(RuntimeError)
      AgentDestroyCleanup.new.perform({user_id: @agent.id})
    end
  ensure
    AgentDestroyCleanup.any_instance.unstub(:destroy_agents_personal_items)
  end

  def test_agent_support_score_destroyed
    assert_nothing_raised do
      AgentDestroyCleanup.any_instance.stubs(:destory_support_scores_in_batches).raises(RuntimeError)
      AgentDestroyCleanup.new.perform(user_id: @agent.id)
    end
  ensure
    AgentDestroyCleanup.any_instance.unstub(:destory_support_scores_in_batches)
  end
end