require_relative '../unit_test_helper'

class BeforeFiltersTest < ActionView::TestCase
  # def test_before_filters
  #     routes = Rails.application.routes.routes.map do |route|
  #       {controller: route.defaults[:controller], action: route.defaults[:action]} if route.app.class == ActionDispatch::Routing::RouteSet::Dispatcher && route.app.instance_variable_get(:@defaults)[:version]
  #     end.compact
  #     routes = routes.group_by{|x| x.delete(:controller)}
  #     routes.each do |controller, actions|
  #       actions.uniq.each do |hash|
  #       # expected_before_filters = get_expected_before_filters(c, hash[:action])
  #       # actual_before_filters = get_actual_before_filters(c, a)
  #       # assert_equal expected_before_filters, actual_before_filters
  #     end
  #   end
  # end
end
