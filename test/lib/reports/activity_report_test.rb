require_relative '../test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')

class ActivityReportsTest < ActionView::TestCase
  include AccountHelper
  include Reports::ActivityReport
  Reports::ChartGenerator::TICKET_COLUMN_MAPPING = {}.freeze

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account = create_test_account
    @@before_all_run = true
  end

  def teardown
    super
  end

  class QueryResult
    def count
      1
    end

    def column
      Account.current.tickets.first.status
    end
  end

  def timeline_columns
    { 'name' => 'value' }
  end

  def params
    {}
  end

  def columns
    ['column']
  end

  def current_account
    Account.current.ticket_fields.nested_fields.new
  end

  def test_fetch_activities
    ActivityReportsTest.any_instance.stubs(:group_tkts_by_columns).returns([QueryResult.new])
    ActivityReportsTest.any_instance.stubs(:count_of_resolved_tickets).returns(1)
    resp = fetch_activity
    assert_equal resp, 1
  ensure
    ActivityReportsTest.any_instance.unstub(:count_of_resolved_tickets)
    ActivityReportsTest.any_instance.unstub(:group_tkts_by_columns)
  end

  def test_get_tickets_time_line
    ActivityReportsTest.any_instance.stubs(:group_tkts_by_timeline).returns([QueryResult.new])
    ActivityReportsTest.any_instance.stubs(:gen_line_chart).returns(true)
    get_tickets_time_line
  ensure
    ActivityReportsTest.any_instance.unstub(:group_tkts_by_timeline)
    ActivityReportsTest.any_instance.unstub(:gen_line_chart)
  end

  def test_get_data_count
    resp = get_data_count(0, 'column', [QueryResult.new], nil, nil)
    assert_equal resp, 0
  end

  def test_get_total_data_count
    resp = get_total_data_count([QueryResult.new])
    assert_equal resp, 1
  end

  def test_calculate_resolved_on_time
    ActivityReportsTest.any_instance.stubs(:count_of_resolved_on_time).returns(2)
    @current_month_tot_tickets = 2
    ActivityReportsTest.any_instance.stubs(:last_month_count_of_resolved_on_time).returns(1)
    ActivityReportsTest.any_instance.stubs(:count_of_tickets_last_month).returns(2)
    ActivityReportsTest.any_instance.stubs(:gen_pie_gauge).returns(50)
    resp = calculate_resolved_on_time
    assert_equal resp, 50
  ensure
    ActivityReportsTest.any_instance.unstub(:gen_pie_gauge)
    ActivityReportsTest.any_instance.unstub(:count_of_resolved_on_time)
    ActivityReportsTest.any_instance.unstub(:last_month_count_of_resolved_on_time)
    ActivityReportsTest.any_instance.unstub(:count_of_tickets_last_month)
  end

  def test_calculate_fcr
    ActivityReportsTest.any_instance.stubs(:count_of_fcr).returns(3)
    @current_month_tot_tickets = 2
    ActivityReportsTest.any_instance.stubs(:count_of_tickets_last_month).returns(1)
    ActivityReportsTest.any_instance.stubs(:last_month_count_of_fcr).returns(1)
    ActivityReportsTest.any_instance.stubs(:gen_pie_gauge).returns(50)
    resp = calculate_fcr
    scoper
    previous_start
    previous_end
    assert_equal resp, 50
  ensure
    ActivityReportsTest.any_instance.unstub(:gen_pie_gauge)
    ActivityReportsTest.any_instance.unstub(:count_of_fcr)
    ActivityReportsTest.any_instance.unstub(:last_month_count_of_fcr)
    ActivityReportsTest.any_instance.unstub(:count_of_tickets_last_month)
  end

  def test_write_io
    resp = write_io
    assert_equal response.status, 200
  end

  def test_export_line_chart_data
    export_line_chart_data(Spreadsheet::Workbook.new.create_worksheet, 0)
    assert_equal response.status, 200
  end

  def test_fill_row
    @pie_chart_labels = {}

    resp = fill_row({ count: {} }, Spreadsheet::Workbook.new.create_worksheet, 'count', 0)
    assert_equal resp, 3
  end
end
