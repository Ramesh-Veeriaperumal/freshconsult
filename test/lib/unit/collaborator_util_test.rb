# frozen_string_literal: true

require_relative '../../api/unit_test_helper'

class CollaboratorUtilTest < ActiveSupport::TestCase
  def setup
    create_test_account if Account.first.nil?
    Account.stubs(:current).returns(Account.first)
    Account.current.agent_types.find_by_name(Collaborators::Constants::COLLABORATOR).try(:destroy)
  end

  def teardown
    Account.current.agent_types.find_by_name(Collaborators::Constants::COLLABORATOR).try(:destroy)
    Account.any_instance.unstub(:has_feature?)
    Account.any_instance.unstub(:launched?)
    Account.unstub(:current)
    super
  end

  def test_enable_collaborators_without_either_feature_doesnt_work
    Account.any_instance.stubs(:has_feature?).with(:collaborators).returns(false)
    Account.any_instance.stubs(:launched?).with(:light_agents).returns(false)
    Collaborators::Util.enable_collaborators
    assert_equal nil, Account.current.agent_types.find_by_name(Collaborators::Constants::COLLABORATOR)

    Account.any_instance.stubs(:has_feature?).with(:collaborators).returns(true)
    Account.any_instance.stubs(:launched?).with(:light_agents).returns(false)
    Collaborators::Util.enable_collaborators
    assert_equal nil, Account.current.agent_types.find_by_name(Collaborators::Constants::COLLABORATOR)

    Account.any_instance.stubs(:has_feature?).with(:collaborators).returns(false)
    Account.any_instance.stubs(:launched?).with(:light_agents).returns(true)
    Collaborators::Util.enable_collaborators
    assert_equal nil, Account.current.agent_types.find_by_name(Collaborators::Constants::COLLABORATOR)
  end

  def test_enable_collaborators_success_scenario
    Account.any_instance.stubs(:has_feature?).with(:collaborators).returns(true)
    Account.any_instance.stubs(:launched?).with(:light_agents).returns(true)
    assert_equal nil, Account.current.agent_types.find_by_name(Collaborators::Constants::COLLABORATOR)
    Collaborators::Util.enable_collaborators
    assert_equal true, Account.current.agent_types.find_by_name(Collaborators::Constants::COLLABORATOR).present?
  end

  def test_enable_collaborators_error
    Account.any_instance.stubs(:has_feature?).with(:collaborators).returns(true)
    Account.any_instance.stubs(:launched?).with(:light_agents).returns(true)
    AgentType.stubs(:create_agent_type).raises(StandardError)
    assert_nothing_raised do
      Collaborators::Util.enable_collaborators
    end
    assert_equal nil, Account.current.reload.agent_types.reload.find_by_name(Collaborators::Constants::COLLABORATOR)
  end

  def test_cleanup_collaborators_does_nothing_for_now
    Account.any_instance.stubs(:has_feature?).with(:collaborators).returns(true)
    Account.any_instance.stubs(:launched?).with(:light_agents).returns(true)
    returned_value = Collaborators::Util.cleanup_collaborators
    assert_equal nil, returned_value
    assert_equal nil, Account.current.agent_types.find_by_name(Collaborators::Constants::COLLABORATOR)
  end
end
