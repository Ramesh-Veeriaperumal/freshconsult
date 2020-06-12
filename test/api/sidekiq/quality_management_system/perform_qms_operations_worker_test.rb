require_relative '../../unit_test_helper'
require_relative '../../test_helper'
require 'sidekiq/testing'
require 'webmock/minitest'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

class PerformQmsOperationsWorkerTest < ActionView::TestCase
  include CoreUsersTestHelper
  include QmsTestHelper

  def setup
    @account = Account.first.presence || create_test_account
    Account.stubs(:current).returns(@account)
    User.stubs(:current).returns(@account.all_technicians.first)
    cleanup_qms
    @account_admin_role = @account.roles.account_admin.first
    @admin_role = @account.roles.admin.first
    @agent_role = @account.roles.agent.first
    @custom_admin_role = create_role(name: Faker::Name.name, privilege_list: ['manage_tickets', 'admin_tasks', '', '0', '0', '0', '0'])
  end

  def teardown
    Account.unstub(:current)
    User.unstub(:current)
    cleanup_qms
    @custom_admin_role.destroy
    super
  end

  def test_qms_feature_added
    assert !check_privileges?
    assert_equal 0, ::Roles::UpdateUserPrivileges.jobs.size
    enable_qms
    reload_objects
    assert ::Roles::UpdateUserPrivileges.jobs.size > 0
    assert Account.current.roles.map(&:name).include?('Coach')
    assert check_privileges?
  ensure
    cleanup_qms
  end

  def test_qms_feature_removed
    enable_qms
    reload_objects
    assert check_privileges?
    add_privileges_to_agent_role
    ::Roles::UpdateUserPrivileges.jobs.clear
    assert_equal 0, ::Roles::UpdateUserPrivileges.jobs.size
    disable_qms
    reload_objects
    assert ::Roles::UpdateUserPrivileges.jobs.size > 0
    assert !@account.roles.map(&:name).include?('Coach')
    assert !check_privileges?
  ensure
    cleanup_qms
  end

  def test_trigger_worker_on_adding_qms
    jobs_count_before = ::QualityManagementSystem::PerformQmsOperationsWorker.jobs.size
    @account.add_feature(:quality_management_system)
    jobs_count_after = ::QualityManagementSystem::PerformQmsOperationsWorker.jobs.size
    assert jobs_count_after = jobs_count_before + 1
  end

  def test_trigger_worker_on_removing_qms
    jobs_count_before = ::QualityManagementSystem::PerformQmsOperationsWorker.jobs.size
    @account.revoke_feature(:quality_management_system)
    jobs_count_after = ::QualityManagementSystem::PerformQmsOperationsWorker.jobs.size
    assert jobs_count_after = jobs_count_before + 1
  end

  private

    def cleanup_qms
      destroy_coach
      disable_qms if @account.quality_management_system_enabled?      
      ::Roles::UpdateUserPrivileges.jobs.clear
    end   

    def destroy_coach
      role = Account.current.roles.coach.first
      role.try(:destroy)
    end

    def account_admin_role_has_qms_privileges?
      @account_admin_role.privilege?(:manage_scorecards) && @account_admin_role.privilege?(:manage_teams)
    end

    def admin_role_has_qms_privileges?
      @admin_role.privilege?(:manage_scorecards) && @admin_role.privilege?(:manage_teams)
    end

    def custom_admin_role_has_qms_privileges?
      @custom_admin_role.privilege?(:manage_scorecards) && @custom_admin_role.privilege?(:manage_teams)
    end

    def check_privileges?
      account_admin_role_has_qms_privileges? && admin_role_has_qms_privileges? && custom_admin_role_has_qms_privileges?
    end

    def reload_objects
      @account.reload
      @account_admin_role.reload
      @admin_role.reload
      @custom_admin_role.reload
      @agent_role.reload
    end

    def create_role(params = {})
      test_role = FactoryGirl.build(:roles, name: params[:name], description: Faker::Lorem.paragraph, privilege_list: params[:privilege_list])
      test_role.save(validate: false)
      test_role
    end

    def add_privileges_to_agent_role
      @agent_role.privilege_list = (@agent_role.abilities + [:view_scores]).flatten
      @agent_role.save
    end
end
