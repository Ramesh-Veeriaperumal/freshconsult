# frozen_string_literal: true

require_relative '../unit_test_helper'
require_relative '../test_helper'
require 'sidekiq/testing'
require 'webmock/minitest'
Sidekiq::Testing.fake!

class PrivelegesModificationWorkerTest < ActionView::TestCase
  include PrivilegesModificationTestHelper

  def setup
    @account = Account.first.presence || create_test_account
    Account.stubs(:current).returns(@account)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_trigger_worker_on_adding_custom_objects
    @account.launch(:symphony)
    jobs_count_before = ::PrivilegesModificationWorker.jobs.size
    @account.add_feature(:custom_objects)
    jobs_count_after = ::PrivilegesModificationWorker.jobs.size
    assert jobs_count_after == jobs_count_before + 1
  ensure
    @account.rollback(:symphony)
  end

  def test_trigger_worker_on_removing_custom_objects
    @account.launch(:symphony)
    jobs_count_before = ::PrivilegesModificationWorker.jobs.size
    @account.revoke_feature(:custom_objects)
    jobs_count_after = ::PrivilegesModificationWorker.jobs.size
    assert jobs_count_after == jobs_count_before + 1
  ensure
    @account.rollback(:symphony)
  end

  def test_trigger_worker_on_adding_custom_objects_should_not_enqueue_without_launch_party
    jobs_count_before = ::PrivilegesModificationWorker.jobs.size
    @account.add_feature(:custom_objects)
    jobs_count_after = ::PrivilegesModificationWorker.jobs.size
    assert jobs_count_after == jobs_count_before
  end

  def test_trigger_worker_on_removing_custom_objects_should_not_enqueue_without_launch_party
    jobs_count_before = ::PrivilegesModificationWorker.jobs.size
    @account.revoke_feature(:custom_objects)
    jobs_count_after = ::PrivilegesModificationWorker.jobs.size
    assert jobs_count_after == jobs_count_before
  end

  def test_admin_role_is_added_on_adding_custom_objects
    disable_custom_objects
    @account.add_feature(:custom_objects)
    ::PrivilegesModificationWorker.new.perform(feature: 'custom_objects')
    @account.roles.each do |role|
      if role.privilege?(:admin_tasks)
        assert role.privilege_list.include? :manage_custom_objects
      else
        assert !(role.privilege_list.include? :manage_custom_objects)
      end
    end
  ensure
    disable_custom_objects
  end

  def test_admin_role_is_removed_on_revoking_custom_objects
    enable_custom_objects
    @account.launch(:symphony)
    @account.revoke_feature(:custom_objects)
    ::PrivilegesModificationWorker.new.perform(feature: 'custom_objects')
    @account.roles.each do |role|
      assert !(role.privilege_list.include? :manage_custom_objects)
    end
  ensure
    disable_custom_objects
  end

  def test_calling_privilege_modification_worker_with_no_method_definition_fails_silently
    assert_nothing_raised do
      ::PrivilegesModificationWorker.new.perform(feature: 'random_test_feature')
    end
  end
end
