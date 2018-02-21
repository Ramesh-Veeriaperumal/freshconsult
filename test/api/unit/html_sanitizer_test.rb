require_relative '../unit_test_helper'

class HtmlSanitizerTest < ActionView::TestCase
  def test_css_if_contains_whitelisted_properties
    controller_params = %[
  <div style="height: 100px; width: 100px; color: green; max-width: 1024px;"></div>
  <p>hello!</p>
]
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    refute html_value.include?('max-width: 1024px;'), 'Max-width trimmed'
    assert html_value.include?('color: green;'), 'color not trimmed'
  end

end
