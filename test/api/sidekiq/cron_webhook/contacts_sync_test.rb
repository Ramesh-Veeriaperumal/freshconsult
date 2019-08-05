require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'installed_applications_test_helper.rb')

Sidekiq::Testing.fake!

class ContactsSyncTest < ActionView::TestCase
  include AccountTestHelper
  include CoreUsersTestHelper
  include InstalledApplicationsTestHelper

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.current
    @user = @account.nil? ? create_test_account : add_new_user(@account)
    @user.make_current
    @account.revoke_feature :marketplace
  end

  def teardown
    @account.add_feature :marketplace
  end

  def test_contacts_sync_trial
    create_application('outlook_contacts')
    ActiveRecord::Base.stubs(:supports_sharding?).returns(false)
    Account.stubs(:trial_accounts).returns([@account.reload])
    Integrations::ContactsSync::Trial.drain
    CronWebhooks::ContactsSync.new.perform(task_name: 'contacts_sync_trial')
    Account.unstub(:trial_accounts)
    ActiveRecord::Base.unstub(:supports_sharding?)
    assert_equal 1, Integrations::ContactsSync::Trial.jobs.size
  end

  def test_contacts_sync_free
    create_application('outlook_contacts')
    ActiveRecord::Base.stubs(:supports_sharding?).returns(false)
    Account.stubs(:free_accounts).returns([@account.reload])
    Integrations::ContactsSync::Free.drain
    CronWebhooks::ContactsSync.new.perform(task_name: 'contacts_sync_free')
    Account.unstub(:free_accounts)
    ActiveRecord::Base.unstub(:supports_sharding?)
    assert_equal 1, Integrations::ContactsSync::Free.jobs.size
  end

  def test_contacts_sync_paid
    create_application('outlook_contacts')
    ActiveRecord::Base.stubs(:supports_sharding?).returns(false)
    Account.stubs(:paid_accounts).returns([@account.reload])
    Integrations::ContactsSync::Paid.drain
    CronWebhooks::ContactsSync.new.perform(task_name: 'contacts_sync_paid')
    Account.unstub(:paid_accounts)
    ActiveRecord::Base.unstub(:supports_sharding?)
    assert_equal 1, Integrations::ContactsSync::Paid.jobs.size
  end
end
