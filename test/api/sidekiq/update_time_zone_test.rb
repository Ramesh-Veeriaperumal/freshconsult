require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

class UpdateTimeZoneTest < ActionView::TestCase
  def setup
    @account = Account.first.make_current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_update_time_zone_worker_runs
    UpdateTimeZone.jobs.clear
    old_time_zone = @account.time_zone
    new_time_zone = 'Hawaii'
    args = build_args(new_time_zone)
    UpdateTimeZone.new.perform(args)
    assert_equal 0, UpdateTimeZone.jobs.size
    assert_equal old_time_zone, @account.time_zone
    args = build_args(old_time_zone)
    UpdateTimeZone.new.perform(args)
    assert_equal 0, UpdateTimeZone.jobs.size
  ensure
    UpdateTimeZone.jobs.clear
  end

  def test_update_time_zone_worker_errors_out_on_exception
    UpdateTimeZone.jobs.clear
    args = nil
    old_time_zone = @account.time_zone
    UpdateTimeZone.new.perform(args)
    assert_equal 0, UpdateTimeZone.jobs.size
    assert_equal old_time_zone, @account.time_zone
  ensure
    UpdateTimeZone.jobs.clear
  end

  def build_args(time_zone)
    { time_zone: time_zone }
  end
end
