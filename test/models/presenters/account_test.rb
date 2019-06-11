require_relative '../test_helper'
require 'faker'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class AccountTest < ActiveSupport::TestCase
  include AccountTestHelper
  
  def test_create
    CentralPublishWorker::AccountWorker.jobs.clear
    create_new_account(Faker::Name.first_name, Faker::Internet.email)
    assert_equal 1, CentralPublishWorker::AccountWorker.jobs.size
    payload = @account.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_account_post(@account))
    assoc_payload = @account.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(central_publish_account_association_pattern(@account))
  end

  def test_add_bitmap_feature
    setup
    @account.revoke_feature(:skill_based_round_robin)
    CentralPublishWorker::AccountWorker.jobs.clear
    @account.add_feature(:skill_based_round_robin)
    assert_equal 1, CentralPublishWorker::AccountWorker.jobs.size
    payload = @account.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_account_post(@account))
    job = CentralPublishWorker::AccountWorker.jobs.last
    assert_equal 'account_update', job['args'][0]
    assert_equal({ 'added' => ["skill_based_round_robin"], 'removed' => [] }, job['args'][1]['model_changes']['features'])
  ensure
     @account.revoke_feature(:skill_based_round_robin)
  end
  
  def test_remove_bitmap_feature
    setup
    @account.add_feature(:skill_based_round_robin)
    CentralPublishWorker::AccountWorker.jobs.clear
    @account.revoke_feature(:skill_based_round_robin)
    assert_equal 1, CentralPublishWorker::AccountWorker.jobs.size
    payload = @account.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_account_post(@account))
    job = CentralPublishWorker::AccountWorker.jobs.last
    assert_equal 'account_update', job['args'][0]
    assert_equal({ 'added' => [], 'removed' => ["skill_based_round_robin"] }, job['args'][1]['model_changes']['features'])
  end
end
