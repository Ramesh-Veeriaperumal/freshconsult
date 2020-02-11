require_relative '../test_helper'
class DashboardAnnouncementTest < ActiveSupport::TestCase
  def test_activerecord_scopes
    Account.reset_current_account
    assert_equal 'SELECT `dashboard_announcements`.* FROM `dashboard_announcements`  WHERE `dashboard_announcements`.`active` = 1', DashboardAnnouncement.active.to_sql
  end
end
