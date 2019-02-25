require_relative '../test_helper'
require 'faker'
require Rails.root.join('spec', 'support', 'user_helper.rb')

class UserTest < ActiveSupport::TestCase
  include UsersHelper

  def test_central_publish_payload
    user = add_new_user(@account)
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_user_pattern(user))
  end

  def test_user_update_without_feature
    @account.rollback(:audit_logs_central_publish)
    CentralPublishWorker::UserWorker.jobs.clear
    update_user
    assert_equal 0, CentralPublishWorker::UserWorker.jobs.size
  ensure
    @account.launch(:audit_logs_central_publish)
  end

  def test_user_update_with_feature
    CentralPublishWorker::UserWorker.jobs.clear
    update_user
    assert_equal 0, CentralPublishWorker::UserWorker.jobs.size
    user = Account.current.technicians.first
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_user_pattern(user))
  end
end
