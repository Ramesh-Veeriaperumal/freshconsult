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

  def test_table_containing_bgcolor_removed_and_pasted_style
    controller_params = %( <table style="padding:5px;width:300px;color:#ffffff;font-size:12px" bgcolor="#EC3710"> )
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    assert html_value.include?('font-size:12px'), 'style present'
    assert html_value.include?('background-color:#EC3710'), 'style added'
    refute html_value.include?('bgcolor="#EC3710"'), 'bgcolor attribute trimmed'
  end

  def test_table_containing_bgcolor_removed_and_style_attribute_added_with_inline_style
    controller_params = %( <table bgcolor="#EC3710"> )
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

  def test_css_if_contains_whitelisted_properties
    controller_params = %(
  <div
    style="height: 100px; width: 100px; color: green; max-width: 1024px;"
    onmouseover="alert(1)"
    class="random"
  ></div>
  <p>hello!</p>
)
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    assert html_value.include?('color: green;'), 'style trimmed'
    assert html_value.include?('class="random"'), 'class trimmed'
    refute html_value.include?('onmouseover="alert(1)"'), 'js events not trimmed'
  end

  def test_css_if_does_not_contains_blacklisted_properties
    controller_params = %[
  <div
    style="height: 100px;position: absolute;z-index:1"
    onmouseover="alert(1)"
    class="random"
  ></div>
  <p>hello!</p>
]
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    refute html_value.include?('position: absolute;'), 'blacklisted css property removed'
    refute html_value.include?('z-index:1'), 'z-index property removed'
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

  def test_css_if_it_ignores_empty_styles
    controller_params = %[
  <div
    style="height: 100px;position: absolute;;margin-left: 25px;margin-right: -50px;"
    onmouseover="alert(1)"
    class="random"
  ></div>
]
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    assert html_value.include?('height: 100px;margin-left: 25px'), 'positive values retained'
    refute html_value.include?('position: absolute'), 'able to ignore the empty styles'
  end

  def test_css_if_it_contains_invalid_styles
    controller_params = %[
  <div
    style="height: 100px;position: absolute;;margin-left: 25px;width color;; transform"
    onmouseover="alert(1)"
    class="random"
  ></div>
]
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    assert html_value.include?('height: 100px;margin-left: 25px'), 'positive values retained'
    refute html_value.include?('width color;; transform'), 'able to handle invalid styles in css'
  end

  def test_css_if_it_contains_only_name_in_the_negative_properties
    controller_params = %(
  <div
    style="height: 100px;position: absolute;;margin:;width color;; transform"
  ></div>
)
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    assert_equal('
  <div style="height: 100px"></div>
', html_value, 'handle negaitve properties with nil')
  end

  def test_css_sanitizer_if_it_is_able_to_handle_junk_invalid_styles
    controller_params = %(
  <div
    style="height: 100px;position: absolute;;margin:;width color;; junk::;;;:::,;;kjbjkbda:;;;;;;:::transform"
  ></div>
)
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    assert_equal('
  <div style="height: 100px"></div>
', html_value, 'handle junk and invalid values')
  end

  def test_css_sanitizer_if_it_is_able_to_handle_case_sensitive_styles
    controller_params = %(
  <div
    style="height: 100px; POSITION: ABSOLUTE"
  ></div>
)
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    assert_equal('
  <div style="height: 100px"></div>
', html_value, 'handle case sensitive styles')
  end

  def test_css_sanitizer_check_if_able_to_parse_quot_in_font_family
    controller_params = %(
  <div
    style="font-size: 10pt; font-family: Arial, sans-serif, &quot;Helvetica Neue&quot;, Helvetica, Arial, sans-serif, &quot;Helvetica Neue&quot;, Helvetica, Arial, sans-serif"
  ></div>
)
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    assert_equal("
  <div style='font-size: 10pt; font-family: Arial, sans-serif, \"Helvetica Neue\", Helvetica, Arial, sans-serif, \"Helvetica Neue\", Helvetica, Arial, sans-serif'></div>
", html_value, 'handle quotes in font-family')
  end

  def test_css_sanitizer_if_it_is_able_strip_off_blacklisted_values_in_style_property
    controller_params = %(
  <div
    style="height: 100px; POSITION: ABSOLUTE; position: Relative;"
  ></div>
)
    html_value = Helpdesk::HTMLSanitizer.clean(controller_params)
    assert html_value.include?('position: Relative'), 'positive values retained'
    refute html_value.include?('POSITION: ABSOLUTE;'), 'blacklisted style value trimmed'
  end
end
