# frozen_string_literal: true

require_relative '../../../api/api_test_helper'

class Admin::TemplatesControllerFlowTest < ActionDispatch::IntegrationTest
  def test_render_show_page
    account_wrap do
      get "/admin/portal/#{@account.main_portal.id}/template"
    end
    assert_response 200
    assert_equal assigns(:falcon_portal_enabled), @account.main_portal.falcon_portal_enable?
    assert_equal assigns(:portal).id, @account.main_portal.id
    assert_equal assigns(:falcon_support_portal_theme_enabled), @account.falcon_support_portal_theme_enabled?
    templates = ['portal/_falcon_header', 'portal/_falcon_footer', 'portal/_falcon_layout', 'portal/_head', '/admin/shared/_customization_buttons', '/admin/shared/_portal_simple', 'admin/templates/_custom_css', 'admin/templates/_layout', 'admin/templates/_portal_pages', '/admin/shared/_sample_portals', 'admin/templates/show', 'layouts/shared/_head', '/notification/_user_notification', '/layouts/shared/_header', '/discussions/shared/_sidebar', '/solution/shared/_navmenu', 'layouts/_tour_my_app', '/search/_navsearch', 'layouts/maincontent', 'layouts/shared/_footer_no_feedback_box', 'shared/_shortcuts_help_chart', 'layouts/shared/_footer', 'layouts/shared/_scripts', 'layouts/_chat', 'layouts/_freshfone_livechat', 'layouts/application']
    templates.each do |template|
      assert_template(template)
    end
  end

  def test_restore_default
    Portal::Template.any_instance.expects(:reset_to_default).once
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template/restore_default"
    end
    assert_response 302
    assert session['flash'][:notice].include?('Portal changes reseted successfully.')
  end

  def test_update_customization
    color = "##{SecureRandom.hex(3)}"
    updated_preferences = @account.main_portal.template.default_preferences.merge(bg_color: color)
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template", portal_tab: 'preferences', portal_template: { preferences: updated_preferences }
    end
    assert_response 200
    assert_equal @account.main_portal.template.get_draft.preferences['bg_color'], color
    assert @account.main_portal.template.get_draft
    Portal::Template.any_instance.expects(:publish!).once
    account_wrap do
      get "/admin/portal/#{@account.main_portal.id}/template/publish"
    end
    assert_response 302
    assert_equal "Portal changes published successfully.", flash[:notice]
    assert_redirected_to "http://localhost.freshpo.com/admin/portal/#{@account.main_portal.id}/template"
  end

  def test_update_customization_without_falcon_support_portal_theme
    Account.any_instance.stubs(:falcon_support_portal_theme_enabled?).returns(false)
    Portal.any_instance.stubs(:falcon_portal_enable?).returns(false)
    color = "##{SecureRandom.hex(3)}"
    updated_preferences = @account.main_portal.template.default_preferences.merge(bg_color: color)
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template", portal_tab: 'preferences', portal_template: { preferences: updated_preferences }
    end
    assert_response 200
    assert_equal @account.main_portal.template.get_draft.preferences['bg_color'], color
    assert @account.main_portal.template.get_draft
  ensure
    Account.any_instance.unstub(:falcon_support_portal_theme_enabled?)
    Portal.any_instance.unstub(:falcon_portal_enable?)
  end

  def test_update_customization_with_preview
    color = "##{SecureRandom.hex(3)}"
    updated_preferences = @account.main_portal.template.default_preferences.merge(bg_color: color)
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template", portal_tab: 'preferences', portal_template: { preferences: updated_preferences }, preview_button: 'Preview'
    end
    assert_response 302
    assert_redirected_to 'http://localhost.freshpo.com/support/preview'
    @account.reload
    assert_equal @account.main_portal.template.get_draft.preferences['bg_color'], color
    assert @account.main_portal.template.get_draft
  end

  def test_update_customization_with_mint_preview
    color = "##{SecureRandom.hex(3)}"
    updated_preferences = @account.main_portal.template.default_preferences.merge(bg_color: color)
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template", portal_tab: 'preferences', portal_template: { preferences: updated_preferences }, mint_preview_button: 'Preview'
    end
    assert_response 302
    assert_redirected_to 'http://localhost.freshpo.com/support/preview?mint_preview=true'
    @account.reload
    assert_equal @account.main_portal.template.get_draft.preferences['bg_color'], color
    assert @account.main_portal.template.get_draft
  end

  def test_update_customization_with_mint_preview_support_mint_applicable_portal
    color = "##{SecureRandom.hex(3)}"
    updated_preferences = @account.main_portal.template.default_preferences.merge(bg_color: color)
    Admin::TemplatesController.any_instance.stubs(:support_mint_applicable_portal?).returns(true)
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template", portal_tab: 'preferences', portal_template: { preferences: updated_preferences }, mint_preview_button: 'Preview'
    end
    assert_response 302
    assert_redirected_to 'http://localhost.freshpo.com/support/preview?mint_preview=true'
    @account.reload
    assert_equal @account.main_portal.template.get_draft.preferences['bg_color'], color
    assert @account.main_portal.template.get_draft
  ensure
    Admin::TemplatesController.any_instance.unstub(:support_mint_applicable_portal?)
  end

  def test_update_customization_with_apply_new_skin
    color = "##{SecureRandom.hex(3)}"
    updated_preferences = @account.main_portal.template.default_preferences.merge(bg_color: color)
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template", portal_tab: 'preferences', portal_template: { preferences: updated_preferences }, apply_new_skin: 'true'
    end
    assert_response 302
    assert_redirected_to 'http://localhost.freshpo.com/support/preview'
    @account.reload
    assert_nil @account.main_portal.template.get_draft
  end

  def test_update_customization_and_publish
    color = "##{SecureRandom.hex(3)}"
    updated_preferences = @account.main_portal.template.default_preferences.merge(bg_color: color)
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template", portal_tab: 'preferences', portal_template: { preferences: updated_preferences }, publish_button: 'Save and Publish'
    end
    assert_response 200
    @account.reload
    assert_equal @account.main_portal.template.preferences[:bg_color], color
    assert_nil @account.main_portal.template.get_draft
  end

  def test_update_with_invalid_liquid_code
    head_code = "<!-- Title for the page -->\n<title> {{ meta.title }} : {{ portal.name }} </title>\n\n<!-- Meta information -->\n{{ meta | default_meta }}\n\n<!-- Responsive setting -->\n{{ portal | default_responsive_settings }}\n\n\t\t\t{% if portal.tabs.size > 0 %}"
    header_code = "{% if  portal.current_page != 'csat_survey' %}\n\t<header class=\"banner\">\n\t\t<div class=\"banner-wrapper page\">\n\t\t\t<div class=\"banner-title\">\n\t\t\t\t{{ portal | logo }}\n\t\t\t\t<h1 class=\"ellipsis heading\">{{portal.name|h}}</h1>\n\t\t\t</div>\n\t\t\t<nav class=\"banner-nav\">\n\t\t\t\t{{ portal | welcome_navigation }}\n\t\t\t</nav>\n\t\t</div>\n\t</header>\n\t<nav class=\"page-tabs\">\n\t\t<div class=\"page no-padding {% if portal.is_not_login_page %}no-header-tabs{% endif %}\">\n\t\t\t{% if portal.tabs.size > 0 %}\n\t\t\t\t<a data-toggle-dom=\"#header-tabs\" href=\"#\" data-animated=\"true\" class=\"mobile-icon-nav-menu show-in-mobile\"></a>\n\t\t\t\t<div class=\"nav-link\" id=\"header-tabs\">\n\t\t\t\t\t{% for tab in portal.tabs %}\n\t\t\t\t\t\t{% if tab.url %}\n\t\t\t\t\t\t\t<a href=\"{{tab.url}}\" class=\"{% if tab.tab_type == portal.current_tab %}active{% endif %}\">{{ tab.label }}</a>\n\t\t\t\t\t\t{% endif %}\n\t\t\t\t\t{% endfor %}\n\t\t\t\t</div>\n\t\t\t{% endif %}\n\t\t</div>\n\t</nav>\n\n<!-- Search and page links for the page -->\n{% if portal.current_tab and portal.current_tab != \"home\" %}\n\t<section class=\"help-center-sc rounded-6\">\n\t\t<div class=\"page no-padding\">\n\t\t<div class=\"hc-search\">\n\t\t\t<div class=\"hc-search-c\">\n\t\t\t\t{% snippet search_form %}\n\t\t\t</div>\n\t\t</div>\n\t\t<div class=\"hc-nav {% if portal.contact_info %} nav-with-contact {% endif %}\">\n\t\t\t{{ portal | helpcenter_navigation }}\n\t\t</div>\n\t\t</div>\n\t</section>\n{% endif %}\n{% else %}\n\t<header class=\"banner\">\n\t\t<div class=\"banner-wrapper\">\n\t\t\t<div class=\"banner-title\">\n\t\t\t\t{{ portal | logo : true }}\n\t\t\t\t<h1 class=\"ellipsis heading\">{{portal.name|h}}</h1>\n\t\t\t</div>\n\t\t</div>\n\t</header>\n{% endif %}\n"
    footer_code = "{% if  portal.current_page != 'csat_survey' %}\n\t<footer class=\"footer rounded-6\">\n\t\t<nav class=\"footer-links page no-padding\">\n\t\t\t{% if portal.tabs.size > 0 %}\n\t\t\t\t\t{% for tab in portal.tabs %}\n\t\t\t\t\t\t<a href=\"{{tab.url}}\" class=\"{% if tab.tab_type == current_tab %}active{% endif %}\">{{ tab.label }}</a>\n\t\t\t\t\t{% endfor %}\n\t\t\t{% endif %}\n\t\t\t{{ portal | link_to_privacy_policy }}\n\t\t\t{{ portal | link_to_cookie_law }}\n\t\t</nav>\n\t</footer>\n\t{{ portal | portal_copyright }}\n{% endif %}"
    layout_code = "{{ header }}\n<div class=\"page\">\n\t\n\t\n\t<!-- Search and page links for the page -->\n\t{% if portal.current_tab and portal.current_tab == \"home\" %}\n\t\t<section class=\"help-center rounded-6\">\t\n\t\t\t<div class=\"hc-search\">\n\t\t\t\t<div class=\"hc-search-c\">\n\t\t\t\t\t<h2 class=\"heading hide-in-mobile\">{% translate header.help_center %}</h2>\n\t\t\t\t\t{% snippet search_form %}\n\t\t\t\t</div>\n\t\t\t</div>\n\t\t\t<div class=\"hc-nav {% if portal.contact_info %} nav-with-contact {% endif %}\">\t\t\t\t\n\t\t\t\t{{ portal | helpcenter_navigation }}\n\t\t\t</div>\n\t\t</section>\n\t{% endif %}\n\n\t<!-- Notification Messages -->\n\t{{ page_message }}\n\n\t{% if portal.current_page != \"user_signup\" and portal.current_page != \"submit_ticket\" %}\n\t<div class=\"c-wrapper\">\t\t\n\t\t{{ content_for_layout }}\n\t</div>\n\t{% elsif portal.current_page == \"submit_ticket\" %}\n\t<div class=\"c-wrapper\">\t\t\n\t\t<div class=\"new_ticket_page\">\n\t\t{{ content_for_layout }}\n\t\t</div>\n\t</div>\n\t{% else %}\n\t<div class=\"signup-page\">\n\t<div class=\"signup-wrapper\">\n\t{{ content_for_layout }}\n\t</div>\n\t</div>\n\t{% endif %}\n\n\t\n\n</div>\n{{ footer }}"
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template", portal_tab: 'layout', portal_template: { head: head_code, header: header_code, footer: footer_code, layout: layout_code }, save_button: 'Save', format: 'js'
    end
    assert_response 200
    assert_equal session['flash'][:error], 'if tag was never closed'
  end

  def test_reset_portal_to_last_published
    initial_color = @account.main_portal.template.preferences[:bg_color]
    color = "##{SecureRandom.hex(3)}"
    updated_preferences = @account.main_portal.template.default_preferences.merge(bg_color: color)
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template", portal_tab: 'preferences', portal_template: { preferences: updated_preferences }, publish_button: 'Save and Publish'
    end
    Portal::Template.any_instance.expects(:clear_preview).once
    Portal::Template.any_instance.expects(:soft_reset!).once
    account_wrap do
      put "/admin/portal/#{@account.main_portal.id}/template/soft_reset", portal_tab: 'preferences', portal_template: ['preferences']
    end
    assert_nil @account.main_portal.template.get_draft
    assert_equal @account.main_portal.template.preferences[:bg_color], initial_color
    assert session['flash'][:notice].include?('Portal changes reseted successfully.')
    assert_response 302
  end

  private

    def old_ui?
      true
    end
end
