# frozen_string_literal: true

require_relative '../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class MiddlewareTest < ActionView::TestCase
  def test_locale_reset
    Account.first.make_current
    ::Sidekiq::Testing.server_middleware do |chain|
      chain.add ::Middleware::Sidekiq::Server::UnsetThread
    end

    I18n.locale = 'fr'
    LaunchPartyActionWorker.perform_async(account_id: 1, features: [])
    LaunchPartyActionWorker.drain
    assert_equal I18n.default_locale, I18n.locale
  end

  def test_central_publish_launch_event_on_launch
    Account.first.make_current
    ::Sidekiq::Testing.server_middleware do |chain|
      chain.add ::Middleware::Sidekiq::Server::UnsetThread
    end

    worker_args = { features: [{ launch: [:agent_statuses] }], account_id: Account.first.id }
    Account.any_instance.stubs(:launched?).with(:agent_statuses).returns(true)
    Account.any_instance.expects(:model_changes=).with(construct_model_changes(:agent_statuses)).once
    Account.any_instance.expects(:manual_publish_to_central).with(nil, :update, nil, false).once
    LaunchPartyActionWorker.new.perform(worker_args)
    LaunchPartyActionWorker.drain
  ensure
    Account.any_instance.unstub(:launched?)
    Account.any_instance.unstub(:model_changes=)
    Account.any_instance.unstub(:manual_publish_to_central)
  end

  def test_central_publish_launch_event_on_rollback
    Account.first.make_current
    ::Sidekiq::Testing.server_middleware do |chain|
      chain.add ::Middleware::Sidekiq::Server::UnsetThread
    end
    worker_args = { features: [{ rollback: [:agent_statuses] }], account_id: Account.first.id }

    Account.any_instance.stubs(:launched?).with(:agent_statuses).returns(false)
    Account.any_instance.expects(:model_changes=).with(construct_model_changes(:agent_statuses)).once
    Account.any_instance.expects(:manual_publish_to_central).with(nil, :update, nil, false).once
    LaunchPartyActionWorker.new.perform(worker_args)
    LaunchPartyActionWorker.drain
  ensure
    Account.any_instance.unstub(:launched?)
    Account.any_instance.unstub(:model_changes=)
    Account.any_instance.unstub(:manual_publish_to_central)
  end

  private

    def construct_model_changes(feature_name)
      changes = {}
      features = { features: { added: [], removed: [] } }
      if Account.current.launched?(feature_name)
        features[:features][:added] << feature_name.to_s
      else
        features[:features][:removed] << feature_name.to_s
      end
      changes.merge!(features)
    end
end
