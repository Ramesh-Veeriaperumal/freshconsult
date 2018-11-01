
require_relative '../unit_test_helper'
require_relative '../test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'groups_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class NewPlanChangeWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include GroupsTestHelper
  def test_round_robin_load_balancing_drop_data
    create_test_account   
    group = @account.groups[0]
    group.capping_limit = 10
    group.ticket_assign_type = 1
    group.save
    SAAS::AccountDataCleanup.new(@account, ["round_robin_load_balancing"], "drop").perform_cleanup
    group.reload
    assert_equal group.capping_limit, 0
    assert_equal group.ticket_assign_type, 0
  end

  def test_round_robin_drop_data   
    create_test_account 
    group = @account.groups[0]
    group.capping_limit = 0
    group.ticket_assign_type = 1
    group.save
    SAAS::AccountDataCleanup.new(@account, ["round_robin"], "drop").perform_cleanup
    group.reload
    assert_equal group.capping_limit, 0
    assert_equal group.ticket_assign_type, 0
  end
		
  def test_in_planchangeworker_round_robin_drop_data
    create_test_account 
    group = @account.groups[0]
    group.capping_limit = 0
    group.ticket_assign_type = 1
    group.save
    PlanChangeWorker.new.perform({:features => ["round_robin", "round_robin_load_balancing"], :action => "drop"})
    group.reload
    assert_equal group.capping_limit, 0
    assert_equal group.ticket_assign_type, 0
  end
end