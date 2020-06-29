require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class TemplatesMigrationWorkerTest < ActionView::TestCase
  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_add_solutions_templates
    Sidekiq::Testing.inline! do
      Account.current.solution_templates.destroy_all
      Solution::TemplatesMigrationWorker.perform_async(account_id: @account.id, action: 'add')
      solution_templates = Account.current.solution_templates
      assert_equal 3, solution_templates.size
    end
  end

  def test_add_solutions_templates_existing
    Sidekiq::Testing.inline! do
      Account.current.solution_templates.destroy_all
      User.stubs(:current).returns(User.first)
      Account.current.solution_templates.build(
        title: '[Sample] User Guide template',
        description: 'sample desc1'
      )
      Account.current.save
      User.unstub(:current)
      Solution::TemplatesMigrationWorker.perform_async(account_id: @account.id, action: 'add')
      solution_templates = Account.current.solution_templates
      assert_equal 3, solution_templates.size
    end
  end

  def drop_solutions_templates
    Sidekiq::Testing.inline! do
      Solution::TemplatesMigrationWorker.perform_async(account_id: @account.id, action: 'drop')
      assert 0, Account.current.solution_templates.size
    end
  end

  def test_add_solutions_templates_with_exception
    Sidekiq::Testing.inline! do
      Solution::TemplatesMigrationWorker.any_instance.stubs(:safe_send).with('add_solutions_templates').raises(StandardError)
      NewRelic::Agent.expects(:notice_error).at_least_once
      Solution::TemplatesMigrationWorker.perform_async(account_id: @account.id, action: 'add')
    end
  ensure
    Solution::TemplatesMigrationWorker.any_instance.unstub(:safe_send)
  end

  def test_add_solutions_without_account_admin
    Account.current.stubs(:account_managers).returns([])
    Sidekiq::Testing.inline! do
      Account.current.solution_templates.destroy_all
      NewRelic::Agent.expects(:notice_error).at_least_once
      Solution::TemplatesMigrationWorker.perform_async(account_id: @account.id, action: 'add')
      solution_templates = Account.current.solution_templates
      assert_equal 0, solution_templates.size
    end
  ensure
    Account.current.unstub(:account_managers)
  end
end
