require_relative '../unit_test_helper'

class HtmlSanitizerTest < ActionView::TestCase
  def test_css_if_contains_whitelisted_properties
    controller_params = %[
  <div
    style="height: 100px; width: 100px; color: green; max-width: 1024px;"
    onmouseover="alert(1)"
    class="random"
  ></div>
  <p>hello!</p>
]
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    assert html_value.include?('color: green;'), 'style trimmed'
    assert html_value.include?('class="random"'), 'class trimmed'
    refute html_value.include?('onmouseover="alert(1)"'), 'js events not trimmed'
  end

  def test_css_if_does_not_contains_blacklisted_properties
    controller_params = %[
  <div
    style="height: 100px;position: absolute;"
    onmouseover="alert(1)"
    class="random"
  ></div>
  <p>hello!</p>
]
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    refute html_value.include?('position: absolute;'), 'blacklisted css property removed'
  end

  def test_css_if_does_not_contains_blacklisted_properties_with_negative_values
    controller_params = %[
  <div
    style="height: 100px;position: absolute;margin-left: 25px;margin-right: -50px;"
    onmouseover="alert(1)"
    class="random"
  ></div>
  <p>hello!</p>
]
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    assert html_value.include?('margin-left: 25px'), 'positive values retained'
    refute html_value.include?('position: absolute;'), 'blacklisted css property removed'
    refute html_value.include?('margin-right: -50px;'), 'negative margins removed'
  end
end
