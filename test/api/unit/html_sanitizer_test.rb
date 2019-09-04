require_relative '../unit_test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')

class HtmlSanitizerTest < ActionView::TestCase
  include AccountHelper

  def setup
    super
    before_all
  end

  @before_all_run = false

  def before_all
    return if @before_all_run
    @account = create_test_account
    @before_all_run = true
  end

  def teardown
    super
  end

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

  def test_table_containing_bgcolor_removed_and_pasted_style
    controller_params = %[ <table style="padding:5px;width:300px;color:#ffffff;font-size:12px" bgcolor="#EC3710"> ]
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    assert html_value.include?('font-size:12px'), 'style present'
    assert html_value.include?('background-color:#EC3710'), 'style added'
    refute html_value.include?('bgcolor="#EC3710"'), 'bgcolor attribute trimmed'
  end

  def test_table_containing_bgcolor_removed_and_style_attribute_added_with_inline_style
    controller_params = %[ <table bgcolor="#EC3710"> ]
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    assert html_value.include?('style'), 'style attribute added to table'
    assert html_value.include?('background-color:#EC3710'), 'style value added'
    refute html_value.include?('bgcolor="#EC3710"'), 'bgcolor attribute trimmed'
  end

  def test_bgcolor_sanitizer_whether_it_can_handle_junk_values
    controller_params = %(
  <table
    style="height: 100px;position: absolute;;margin:;width color;; junk::;;;:::,;;kjbjkbda:;;;;;;:::transform" bgcolor="#EC3710"
  ></table>
)
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    assert html_value.include?('background-color:#EC3710'), 'style value added'
    refute html_value.include?('bgcolor="#EC3710"'), 'bgcolor attribute trimmed'
  end

  def test_bgcolor_sanitizer_if_bgcolor_attribute_metioned_in_capital_letters
    controller_params = %(
  <table
    style="padding:5px;width:300px;color:#ffffff;" BGCOLOR="#EC3710"
  ></table>
)
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    assert html_value.include?('background-color:#EC3710'), 'style value added'
    refute html_value.include?('bgcolor="#EC3710"'), 'bgcolor attribute trimmed'
  end

  def test_bgcolor_sanitizer_if_background_color_already_mentioned
    controller_params = %(
  <table
    style="padding:5px;width:300px;background-color:#000;" bgcolor="#EC3710"
  ></table>
)
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    assert html_value.include?('background-color:#000'), 'existing background style is present'
    assert html_value.include?('background-color:#EC3710'), 'style value added'
    refute html_value.include?('bgcolor="#EC3710"'), 'bgcolor attribute trimmed'
  end
end
