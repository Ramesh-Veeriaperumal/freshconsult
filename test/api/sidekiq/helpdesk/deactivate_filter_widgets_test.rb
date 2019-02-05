require_relative '../../unit_test_helper'
require_relative '../../../test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'api', 'helpers', 'custom_dashboard_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'custom_dashboard', 'dashboard_object.rb')
require Rails.root.join('test', 'api', 'helpers', 'custom_dashboard', 'widget_object.rb')

class SidekiqDeactivateFilterWidgetsTest < ActionView::TestCase
  include CustomDashboardTestHelper

  def setup
    super
    initial_setup
  end

  def initial_setup
    @account = Account.first.make_current
  end

  def dashboard_list
    @@dashboard_list ||= []
  end

  def update_dashboard_list(dashboard_object)
    self.dashboard_list << dashboard_object
  end

  def test_deactivate_filter_widgets
    options = { ticket_filter_id: 8, threshold_min: 100, threshold_max: 150 }
    scorecard_dashboard = create_dashboard_with_widgets(nil, 1, 0, [options])
    Sidekiq::Testing.inline! do
      Helpdesk::DeactivateFilterWidgets.new.perform(filter_id: 8)
    end
    assert_equal scorecard_dashboard.widgets.first.active, false
  ensure
    scorecard_dashboard.destroy
  end

  def test_deactivate_filter_widgets_with_different_filter
    options = { ticket_filter_id: 8, threshold_min: 100, threshold_max: 150 }
    barchart_dashboard = create_dashboard_with_widgets(nil, 1, 1)
    Sidekiq::Testing.inline! do
      Helpdesk::DeactivateFilterWidgets.new.perform(filter_id: 9)
    end
    assert_equal barchart_dashboard.widgets.first.active, true
  ensure
    barchart_dashboard.destroy
  end

  def test_deactivate_filter_widgets_with_exception
    assert_raises(RuntimeError) do
      options = { ticket_filter_id: 8, threshold_min: 100, threshold_max: 150 }
      barchart_dashboard = create_dashboard_with_widgets(nil, 1, 1)
      Account.any_instance.stubs(:dashboard_widgets).raises(RuntimeError)
      Helpdesk::DeactivateFilterWidgets.new.perform(filter_id: 9)
      Account.any_instance.unstub(:dashboard_widgets)
    end
  end
end
