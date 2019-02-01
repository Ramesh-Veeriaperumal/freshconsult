require_relative '../../unit_test_helper'
require_relative '../../../test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'api', 'helpers', 'custom_dashboard_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'custom_dashboard', 'dashboard_object.rb')
require Rails.root.join('test', 'api', 'helpers', 'custom_dashboard', 'widget_object.rb')

class SidekiqDeactivateProductWidgetsTest < ActionView::TestCase
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

  def test_product_widgets_deactivate
    ticket_trend_card_dashboard = create_dashboard_with_widgets(nil, 1, 5)
    Sidekiq::Testing.inline! do
      Helpdesk::DeactivateProductWidgets.new.perform(product_id: 1)
    end
    assert_equal ticket_trend_card_dashboard.widgets.first.active, false
  ensure
    ticket_trend_card_dashboard.destroy
  end

  def test_product_widgets_deactivate_with_different_product_id
    time_trend_card_dashboard = create_dashboard_with_widgets(nil, 1, 6)
    Sidekiq::Testing.inline! do
      Helpdesk::DeactivateProductWidgets.new.perform(product_id: 2)
    end
    assert_equal time_trend_card_dashboard.widgets.first.active, true
  ensure
    time_trend_card_dashboard.destroy
  end

  def test_deactivate_product_widgets_with_exception
    time_trend_card_dashboard = create_dashboard_with_widgets(nil, 1, 6)
    Account.any_instance.stubs(:dashboards).raises(RuntimeError)
    assert_nothing_raised do
      Helpdesk::DeactivateProductWidgets.new.perform(product_id: 2)
    end
    Account.any_instance.unstub(:dashboards)
  end
end
