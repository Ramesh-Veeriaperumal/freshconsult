require_relative '../test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')

class PlanChangeWorkerTest < ActionView::TestCase
  include AccountHelper
  include UsersTestHelper
  
  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    create_test_account
    @@before_all_run = true
  end

  def teardown
    super
  end

  def test_perform
    PlanChangeWorker.new.perform({ 'features' => ['feature1', 'feature2'], 'action' => 'act' })
    assert_equal response.status, 200
    PlanChangeWorker.any_instance.stubs(:respond_to?).raises(Exception)
    PlanChangeWorker.new.perform({ 'features' => ['feature1', 'feature2'], 'action' => 'act' })
  ensure
    PlanChangeWorker.any_instance.unstub(:respond_to?)
  end

  def test_update_all_in_batches
    PlanChangeWorker.new.frame_conditions({ 'batch_size' => 1, 'key_only' => nil, 'key' => 'val' })
  end

  def test_drop_css_customization_data
    PlanChangeWorker.new.drop_css_customization_data(Account.current)
  end

  def test_add_round_robin_data
    Role.stubs(:add_manage_availability_privilege).returns(true)
    PlanChangeWorker.new.add_round_robin_data(Account.current)
    assert_equal response.status, 200
  ensure
    Role.unstub(:aadd_manage_availability_privilege)
  end

  def test_drop_multi_timezone_data
    UpdateTimeZone.stubs(:perform_async).returns(true)
    PlanChangeWorker.new.drop_multi_timezone_data(Account.current)
    assert_equal response.status, 200
  ensure
    UpdateTimeZone.unstub(:perform_async)
  end

  def test_drop_round_robin_data
    Role.stubs(:remove_manage_availability_privilege).returns(true)
    PlanChangeWorker.new.drop_round_robin_data(Account.current)
  ensure
    Role.unstub(:remove_manage_availability_privilege)
  end

  def test_drop_facebook_data
    PlanChangeWorker.new.drop_facebook_data(Account.current)
  end

  def test_drop_twitter_data
    Social::TwitterHandle.stubs(:drop_advanced_twitter_data).returns(true)
    PlanChangeWorker.new.drop_twitter_data(Account.current)
  ensure
    Social::TwitterHandle.unstub(:drop_advanced_twitter_data)
  end

  def test_drop_custom_domain_data
    Account.any_instance.stubs(:save!).returns(true)
    PlanChangeWorker.new.drop_custom_domain_data(Account.current)
  ensure
    Account.any_instance.unstub(:save!)
  end

  def test_drop_custom_roles_data
    PlanChangeWorker.new.drop_custom_roles_data(Account.current)
  end

  def test_drop_dynamic_sections_data
    PlanChangeWorker.new.drop_dynamic_sections_data(Account.current)
  end

  def test_drop_helpdesk_restriction_toggle_data
    PlanChangeWorker.new.drop_helpdesk_restriction_toggle_data(Account.current)
  end

  def test_drop_mailbox_data
    PlanChangeWorker.new.drop_mailbox_data(Account.current)
  end
end
