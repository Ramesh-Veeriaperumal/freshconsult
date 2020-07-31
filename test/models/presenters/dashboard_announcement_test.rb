require_relative '../test_helper'
require Rails.root.join('test', 'models', 'helpers', 'users_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class DashboardAnnouncementTest < ActiveSupport::TestCase
  include ModelsUsersTestHelper
  include AccountTestHelper

  def test_dashboard_central_publish
    Account.stubs(:current).returns(Account.first || create_test_account)
    User.stubs(:current).returns(User.first || add_test_agent(Account.current))
    CentralPublisher::Worker.jobs.clear
    dashboard = Account.current.dashboards.new(name: Faker::Lorem.characters(10))
    dashboard.save
    dashboard_announcement = dashboard.announcements.new(user_id:           User.current.id,
                                                         announcement_text: Faker::Lorem.characters(10),
                                                         active:            true)
    dashboard_announcement.save
    assert_equal 1, CentralPublisher::Worker.jobs.size
    assert_equal 'dashboard_announcement_create', CentralPublisher::Worker.jobs.last['args'][0]
  ensure
    Account.unstub(:current)
    User.unstub(:current)
  end
end
