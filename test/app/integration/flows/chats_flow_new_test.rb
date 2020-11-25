# frozen_string_literal: true

require_relative '../../../api/api_test_helper'
require Rails.root.join('test', 'api', 'helpers', 'test_case_methods.rb')
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'chat_test_helper.rb')
class ChatsControllerFlowTest < ActionDispatch::IntegrationTest
  include ChatTestHelper
  include GroupsTestHelper
  include UsersHelper
  include ProductsHelper
  # ------------- INDEX ---------------- #
  def test_index
    Account.current.add_feature(:chat)
    create_chat_widget
    account_wrap do
      get '/livechat'
    end
    assert_response 200
    assert_template :index
    widget_values = Account.current.chat_widgets.reject { |c| c.widget_id.nil? }.collect { |c| [c.widget_id, (c.product.blank? ? Account.current.name : c.product.name)] }
    widgets = Hash[widget_values.map { |i| [i[0], i[1]] }].to_json
    widgets_select_option = widget_values.map { |i| [i[1], i[0]] }
    agents_available = Account.current.agents_from_cache.collect { |c| [c.user.name, c.user.id] }
    export_date_limit = ChatSetting::EXPORT_DATE_LIMIT
    assert_equal :dashboard, assigns[:selected_tab]
    assert_equal widgets, assigns[:widgets]
    assert_equal widgets_select_option, assigns[:widgetsSelectOption]
    assert_equal agents_available, assigns[:agentsAvailable]
    assert_equal export_date_limit, assigns[:export_date_limit]
  end

  def test_index_without_chat_widgets
    Account.any_instance.stubs(:chat_widgets).returns([])
    Account.current.add_feature(:chat)
    account_wrap do
      get '/livechat'
    end
    assert_response 404
  ensure
    Account.any_instance.unstub(:chat_widgets)
  end

  def test_index_with_suspended_account
    Subscription.any_instance.stubs(:suspended?).returns(true)
    Account.current.add_feature(:chat)
    create_chat_widget(site_id: nil)
    account_wrap do
      get '/livechat'
    end
    assert_response 404
  ensure
    Subscription.any_instance.unstub(:suspended?)
  end

  def test_index_without_chat_feature
    Account.current.revoke_feature(:chat)
    account_wrap do
      get '/livechat'
    end
    assert_response 404
  end

  def test_index_without_site_id_in_chat_settings
    Account.current.add_feature(:chat)
    create_chat_widget(site_id: nil)
    account_wrap do
      get '/livechat'
    end
    assert_response 404
  end

  def test_index_without_login
    Account.current.add_feature(:chat)
    create_chat_widget(site_id: nil)
    reset_request_headers
    account_wrap do
      get '/livechat'
    end
    assert_response 302
    assert_equal "http://#{@account.full_domain}/support/login", response.location
  end

  # ------------- CREATE SHORTCODE ---------------- #

  def test_create_shortcode
    stub_http_request
    account_wrap do
      post '/livechat/shortcodes/', create_shortcode_params
    end
    assert_response 200
    match_json(response_hash)
  ensure
    unstub_http_request
  end

  def test_create_shortcode_without_admin_privilege
    User.any_instance.stubs(:privilege?).returns(true)
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    stub_http_request
    account_wrap do
      post '/livechat/shortcodes/', create_shortcode_params
    end
    assert_response 403
    parsed_response = JSON.parse(response.body)
    assert_equal 'only_admin_can_create_shortcodes', parsed_response['code']
  ensure
    User.any_instance.unstub(:privilege?)
    unstub_http_request
  end

  def test_create_shortcode_fails
    stub_http_request(sucess: false, status: 400)
    account_wrap do
      post '/livechat/shortcodes/', create_shortcode_params
    end
    assert_response 400
  ensure
    unstub_http_request
  end

  def test_create_shortcode_without_login
    reset_request_headers
    account_wrap do
      post '/livechat/shortcodes/', create_shortcode_params
    end
    assert_response 302
    assert_equal "http://#{@account.full_domain}/support/login", response.location
  end

  # ------------- DELETE SHORTCODE ---------------- #

  def test_delete_shortcode
    stub_http_request
    account_wrap do
      delete '/livechat/shortcodes/1', delete_shortcode_params(User.current.id)
    end
    assert_response 200
  ensure
    unstub_http_request
  end

  def test_delete_shortcode_without_admin_privilege
    User.any_instance.stubs(:privilege?).returns(true)
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    stub_http_request
    account_wrap do
      delete '/livechat/shortcodes/1', delete_shortcode_params(User.current.id)
    end
    assert_response 403
    parsed_response = JSON.parse(response.body)
    assert_equal 'only_admin_can_create_shortcodes', parsed_response['code']
  ensure
    User.any_instance.unstub(:privilege?)
    unstub_http_request
  end

  def test_delete_shortcode_fails
    stub_http_request(sucess: false, status: 400)
    account_wrap do
      delete '/livechat/shortcodes/1', delete_shortcode_params(User.current.id)
    end
    assert_response 400
  ensure
    unstub_http_request
  end

  def test_delete_shortcode_without_login
    stub_http_request
    reset_request_headers
    account_wrap do
      delete '/livechat/shortcodes/1', delete_shortcode_params(User.current.id)
    end
    assert_response 302
    assert_equal "http://#{@account.full_domain}/support/login", response.location
  ensure
    unstub_http_request
  end

  # ------------- UPDATE SHORTCODE ---------------- #

  def test_update_shortcode
    stub_http_request
    account_wrap do
      put '/livechat/shortcodes/1', update_shortcode_params(User.current.id)
    end
    assert_response 200
    match_json(response_hash)
  ensure
    unstub_http_request
  end

  def test_update_shortcode_without_admin_privilege
    User.any_instance.stubs(:privilege?).returns(true)
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    stub_http_request
    account_wrap do
      put '/livechat/shortcodes/1', update_shortcode_params(User.current.id)
    end
    assert_response 403
    parsed_response = JSON.parse(response.body)
    assert_equal 'only_admin_can_create_shortcodes', parsed_response['code']
  ensure
    User.any_instance.unstub(:privilege?)
    unstub_http_request
  end

  def test_update_shortcode_fails
    stub_http_request(sucess: false, status: 400)
    account_wrap do
      put '/livechat/shortcodes/1', update_shortcode_params(User.current.id)
    end
    assert_response 400
  ensure
    unstub_http_request
  end

  def test_update_shortcode_without_login
    stub_http_request
    reset_request_headers
    account_wrap do
      put '/livechat/shortcodes/1', update_shortcode_params(User.current.id)
    end
    assert_response 302
    assert_equal "http://#{@account.full_domain}/support/login", response.location
  ensure
    unstub_http_request
  end

  # ------------- UPDATE AVAILABILITY ---------------- #

  def test_update_availability
    stub_http_request
    account_wrap do
      put "/livechat/agent/#{User.current.id}/update_availability", update_availability_params(User.current.id)
    end
    assert_response 200
    match_json(response_hash)
  ensure
    unstub_http_request
  end

  def test_update_availability_fails
    stub_http_request(sucess: false, status: 400)
    account_wrap do
      put "/livechat/agent/#{User.current.id}/update_availability", update_availability_params(User.current.id)
    end
    assert_response 400
  ensure
    unstub_http_request
  end

  def test_update_availability_without_login
    stub_http_request
    reset_request_headers
    account_wrap do
      put "/livechat/agent/#{User.current.id}/update_availability", update_availability_params(User.current.id)
    end
    assert_response 302
    assert_equal "http://#{@account.full_domain}/support/login", response.location
  ensure
    unstub_http_request
  end

  # ------------- DOWNLOAD EXPORT ---------------- #

  def test_download_export
    add_url = '/abc.com'
    stub_http_request(add_url: add_url)
    account_wrap do
      get 'livechat/downloadexport/SAAASSSSSAAA'
    end
    assert_response 302
    assert_equal "http://#{@account.full_domain}#{add_url}", response.location
  ensure
    unstub_http_request
  end

  def test_download_export_fails
    stub_http_request(sucess: false)
    account_wrap do
      get 'livechat/downloadexport/SAAASSSSSAAA'
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal 'error', parsed_response['status']
    assert_equal 'Error while downloading export!', parsed_response['message']
  ensure
    unstub_http_request
  end

  def test_download_export_without_login
    add_url = '/abc.com'
    stub_http_request(add_url: add_url)
    reset_request_headers
    account_wrap do
      get 'livechat/downloadexport/SAAASSSSSAAA'
    end
    assert_response 302
    assert_equal "http://#{@account.full_domain}/support/login", response.location
  ensure
    unstub_http_request
  end

  # ------------- EXPORT ---------------- #

  def test_export
    stub_http_request
    account_wrap do
      get '/livechat/export', export_params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal 'success', parsed_response['status']
  ensure
    unstub_http_request
  end

  def test_export_fails
    stub_http_request(sucess: false)
    account_wrap do
      get '/livechat/export', export_params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal 'error', parsed_response['status']
  ensure
    unstub_http_request
  end

  # ------------- TRIGGER ---------------- #

  # 1. recheck_activation

  def test_trigger_recheck_activation
    params = trigger_params(event_type: 'recheck_activation')
    account_wrap do
      put '/livechat/trigger', params
    end
    assert_response 200
    assert JSON.parse(response.body)['status']
    assert Account.current.chat_setting.enabled
    assert_equal params[:site_id], Account.current.chat_setting.site_id
    assert_equal params[:content][:widget_id].to_s, Account.current.main_chat_widget.widget_id
  end

  def test_trigger_recheck_activation_with_content_as_string
    params = trigger_params(event_type: 'recheck_activation', content_as_json: true)
    account_wrap do
      put '/livechat/trigger', params
    end
    assert_response 200
    assert JSON.parse(response.body)['status']
    assert Account.current.chat_setting.enabled
    assert_equal params[:site_id], Account.current.chat_setting.site_id
    assert_equal JSON.parse(params[:content])['widget_id'].to_s, Account.current.main_chat_widget.widget_id
  end

  def test_trigger_recheck_activation_for_chat_setting_without_site_id
    account_wrap do
      put '/livechat/trigger', trigger_params(event_type: 'recheck_activation', empty_site: true)
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal 'error', parsed_response['status']
    assert_equal 'Authentication Failed', parsed_response['message']
  end

  def test_trigger_recheck_activation_without_widget_id_in_param
    params = trigger_params(event_type: 'recheck_activation', widget_id: nil)
    account_wrap do
      put '/livechat/trigger', params
    end
    assert_response 200
    assert JSON.parse(response.body)['status']
    assert Account.current.chat_setting.enabled
    assert_equal params[:site_id], Account.current.chat_setting.site_id
  end

  def test_trigger_recheck_activation_while_main_chat_widget_is_already_mapped_to_a_widget
    widget = @account.main_chat_widget
    widget.widget_id = 123
    widget.save
    params = trigger_params(event_type: 'recheck_activation')
    account_wrap do
      put '/livechat/trigger', params
    end
    assert_response 200
    assert JSON.parse(response.body)['status']
    assert Account.current.chat_setting.enabled
    assert_equal params[:site_id], Account.current.chat_setting.site_id
    refute_equal params[:widget_id].to_s, Account.current.main_chat_widget.widget_id
  end

  def test_trigger_recheck_widget_activation_with_site_id_update_fails
    ChatSetting.any_instance.stubs(:update_attributes).returns(false)
    account_wrap do
      put '/livechat/trigger', trigger_params(event_type: 'recheck_activation')
    end
    assert_response 200
    assert_equal false, JSON.parse(response.body)['status']
  ensure
    ChatSetting.any_instance.unstub(:update_attributes)
  end

  def test_recheck_activation_widget_id_update_fails
    ChatWidget.any_instance.stubs(:update_attributes).returns(false)
    account_wrap do
      put '/livechat/trigger', trigger_params(event_type: 'recheck_activation')
    end
    assert_response 200
    assert_equal false, JSON.parse(response.body)['status']
  ensure
    ChatSetting.any_instance.unstub(:update_attributes)
  end

  def test_trigger_recheck_activation_without_login
    params = trigger_params(event_type: 'recheck_activation')
    reset_request_headers
    account_wrap do
      put '/livechat/trigger', params
    end
    refute_equal 302, response.status
    refute_equal "http://#{@account.full_domain}/support/login", response.location
  end

  # 2. recheck_widget_activation

  def test_trigger_recheck_widget_activation
    widget = create_chat_widget(widget_id: nil, associate_product: true)
    params = trigger_params(event_type: 'recheck_widget_activation')
    params[:content] = params[:content].merge(product_id: widget.product_id, widget_id: 2)
    account_wrap do
      put '/livechat/trigger', params
    end
    assert_response 200
    assert JSON.parse(response.body)['status']
    assert_equal params[:content][:widget_id].to_s, widget.reload.widget_id
  end

  def test_trigger_recheck_widget_activation_for_chat_widgets_with_widget_id
    widget = create_chat_widget(associate_product: true)
    params = trigger_params(event_type: 'recheck_widget_activation')
    params[:content] = params[:content].merge(product_id: widget.product_id, widget_id: 100)
    account_wrap do
      put '/livechat/trigger', params
    end
    assert_response 200
    assert JSON.parse(response.body)['status']
    refute_equal params[:content][:widget_id].to_s, widget.reload.widget_id
  end

  def test_trigger_recheck_widget_activation_fails
    ChatWidget.any_instance.stubs(:update_attributes).returns(false)
    widget = create_chat_widget(widget_id: nil, associate_product: true)
    params = trigger_params(event_type: 'recheck_widget_activation')
    params[:content] = params[:content].merge(product_id: widget.product_id, widget_id: 2)
    account_wrap do
      put '/livechat/trigger', params
    end
    assert_response 200
    assert_equal false, JSON.parse(response.body)['status']
  ensure
    ChatSetting.any_instance.unstub(:update_attributes)
  end

  def test_trigger_recheck_widget_activation_without_login
    widget = create_chat_widget(widget_id: nil, associate_product: true)
    params = trigger_params(event_type: 'recheck_widget_activation')
    params[:content] = params[:content].merge(product_id: widget.product_id, widget_id: 2)
    reset_request_headers
    account_wrap do
      put '/livechat/trigger', params
    end
    refute_equal 302, response.status
    refute_equal "http://#{@account.full_domain}/support/login", response.location
  end

  # 3. trigger_chat_note

  def test_trigger_chat_note
    ticket = create_ticket
    params = trigger_params(event_type: 'chat_note', ticket_id: ticket.display_id)
    account_wrap do
      put '/livechat/trigger', params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal true, parsed_response['status']
    assert_equal ticket.display_id, parsed_response['ticket_id']
    assert_include ticket.notes.first.body, params[:content][:messages].first[:msg]
  end

  def test_trigger_chat_note_fails
    Helpdesk::Note.any_instance.stubs(:save_note).returns(false)
    ticket = create_ticket
    params = trigger_params(event_type: 'chat_note', ticket_id: ticket.display_id)
    account_wrap do
      put '/livechat/trigger', params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal false, parsed_response['status']
    assert_equal ticket.display_id, parsed_response['ticket_id']
    assert_empty ticket.notes
  ensure
    Helpdesk::Note.any_instance.unstub(:save_note)
  end

  def test_trigger_chat_note_without_login
    ticket = create_ticket
    params = trigger_params(event_type: 'chat_note', ticket_id: ticket.display_id)
    reset_request_headers
    account_wrap do
      put '/livechat/trigger', params
    end
    refute_equal 302, response.status
    refute_equal "http://#{@account.full_domain}/support/login", response.location
  end

  # 4. trigger_missed_chat

  def test_trigger_missed_chat_wih_email_not_permisible
    Account.any_instance.stubs(:restricted_helpdesk?).returns(true)
    account_wrap do
      put '/livechat/trigger', trigger_params(event_type: 'missed_chat')
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal 'error', parsed_response['status']
    assert_equal 'User email does not belong to a supported domain.', parsed_response['message']
  ensure
    Account.any_instance.unstub(:restricted_helpdesk?)
  end

  def test_trigger_missed_chat_with_type_as_offline
    params = trigger_params(event_type: 'missed_chat')
    account_wrap do
      put '/livechat/trigger', params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal true, parsed_response['status']
    ticket_created = Account.current.tickets.find_by_display_id(parsed_response['external_id'])
    assert_equal Helpdesk::Source::CHAT, ticket_created.source
    assert_include ticket_created.description, I18n.t('livechat.offline_chat_content', visitor_name: params[:content][:name])
  end

  def test_trigger_missed_chat_with_type_as_online
    params = trigger_params(event_type: 'missed_chat', chat_type: 'online')
    account_wrap do
      put '/livechat/trigger', params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal true, parsed_response['status']
    ticket_created = Account.current.tickets.find_by_display_id(parsed_response['external_id'])
    assert_equal Helpdesk::Source::CHAT, ticket_created.source
    assert_include ticket_created.description, I18n.t('livechat.missed_chat_content', visitor_name: params[:content][:name])
  end

  def test_trigger_missed_chat_without_messages
    params = trigger_params(event_type: 'missed_chat', add_message: false)
    account_wrap do
      put '/livechat/trigger', params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal true, parsed_response['status']
    ticket_created = Account.current.tickets.find_by_display_id(parsed_response['external_id'])
    assert_equal Helpdesk::Source::CHAT, ticket_created.source
    assert_equal ticket_created.description, I18n.t('livechat.offline_chat_content', visitor_name: params[:content][:name])
  end

  def test_trigger_missed_chat_with_group_id
    group = create_group(Account.current)
    account_wrap do
      put '/livechat/trigger', trigger_params(event_type: 'missed_chat', group_id: group.id)
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal true, parsed_response['status']
    ticket_created = Account.current.tickets.find_by_display_id(parsed_response['external_id'])
    assert_equal Helpdesk::Source::CHAT, ticket_created.source
    assert_equal group.id, ticket_created.group_id
  end

  def test_trigger_missed_chat_with_widget_mapped_to_product
    chat_widget = create_chat_widget(widget_id: 202, associate_product: true)
    account_wrap do
      put '/livechat/trigger', trigger_params(event_type: 'missed_chat', widget_id: chat_widget.widget_id)
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal true, parsed_response['status']
    ticket_created = Account.current.tickets.find_by_display_id(parsed_response['external_id'])
    assert_equal Helpdesk::Source::CHAT, ticket_created.source
    assert_equal chat_widget.product_id, ticket_created.product_id
  end

  def test_trigger_missed_chat_fails
    Helpdesk::Ticket.any_instance.stubs(:save_ticket).returns(false)
    account_wrap do
      put '/livechat/trigger', trigger_params(event_type: 'missed_chat')
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal false, parsed_response['status']
    assert_nil parsed_response['external_id']
  ensure
    Helpdesk::Ticket.any_instance.unstub(:save_ticket)
  end

  def test_trigger_missed_chat_without_login
    params = trigger_params(event_type: 'missed_chat', chat_type: 'online')
    reset_request_headers
    account_wrap do
      put '/livechat/trigger', params
    end
    refute_equal 302, response.status
    refute_equal "http://#{@account.full_domain}/support/login", response.location
  end

  # ------------- TOGGLE ---------------- #

  def test_toggle_off
    chat_setting = Account.current.chat_setting
    chat_setting.site_id = 1
    chat_setting.save
    stub_http_request
    account_wrap do
      put '/livechat/toggle', toggle_params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal 'success', parsed_response['status']
    assert_equal false, chat_setting.reload.enabled
  ensure
    unstub_http_request
  end

  def test_toggle_on
    chat_setting = Account.current.chat_setting
    chat_setting.site_id = 1
    chat_setting.save
    stub_http_request
    account_wrap do
      put '/livechat/toggle', toggle_params(true)
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal 'success', parsed_response['status']
    assert_equal true, chat_setting.reload.enabled
  ensure
    unstub_http_request
  end

  def test_toggle_fails
    chat_setting = Account.current.chat_setting
    chat_setting.site_id = 1
    chat_setting.save
    stub_http_request(sucess: false)
    account_wrap do
      put '/livechat/toggle', toggle_params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal 'error', parsed_response['status']
  ensure
    unstub_http_request
  end

  def test_toggle_off_without_login
    chat_setting = Account.current.chat_setting
    chat_setting.site_id = 1
    chat_setting.save
    stub_http_request(sucess: false)
    reset_request_headers
    account_wrap do
      put '/livechat/toggle', toggle_params
    end
    refute_equal 302, response.status
    refute_equal "http://#{@account.full_domain}/support/login", response.location
  end

  # ------------- UPDATE SITE ---------------- #

  def test_update_site
    chat_setting = Account.current.chat_setting
    chat_setting.site_id = 1
    chat_setting.save
    stub_http_request
    account_wrap do
      put '/livechat/update_site', update_site_params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal 'success', parsed_response['status']
  ensure
    unstub_http_request
  end

  def test_update_site_fails
    chat_setting = Account.current.chat_setting
    chat_setting.site_id = 1
    chat_setting.save
    stub_http_request(sucess: false)
    account_wrap do
      put '/livechat/update_site', update_site_params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal 'error', parsed_response['status']
  ensure
    unstub_http_request
  end

  def test_update_site_without_login
    stub_http_request
    reset_request_headers
    account_wrap do
      put '/livechat/update_site', update_site_params
    end
    assert_response 302
    assert_equal "http://#{@account.full_domain}/support/login", response.location
  ensure
    unstub_http_request
  end

  # ------------- GET GROUPS ---------------- #

  def test_get_groups
    create_group(Account.current)
    account_wrap do
      get '/livechat/get_groups'
    end
    assert_response 200
    match_json('groups' => groups_response)
  end

  def test_get_groups_without_login
    reset_request_headers
    account_wrap do
      get '/livechat/get_groups'
    end
    assert_response 302
    assert_equal "http://#{@account.full_domain}/support/login", response.location
  end

  # ------------- VISITOR ---------------- #

  def test_visitor
    account_wrap do
      get '/livechat/visitor/returnVisitor'
    end
    assert_response 200
    assert_equal :dashboard, assigns(:selected_tab)
  end

  def test_visitor_without_login
    reset_request_headers
    account_wrap do
      get '/livechat/visitor/returnVisitor'
    end
    assert_response 302
    assert_equal "http://#{@account.full_domain}/support/login", response.location
  end

  # ------------- ENABLE ---------------- #

  def test_enable_sucess
    create_product
    job_size = LivechatWorker.jobs.size
    response_data = stub_http_request
    account_wrap do
      post '/livechat/enable'
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal 'success', parsed_response['status']
    assert Account.current.chat_setting.active
    assert Account.current.chat_setting.enabled
    assert_equal response_data['data']['site']['site_id'], Account.current.chat_setting.site_id
    assert_equal response_data['data']['widget']['widget_id'].to_s, Account.current.main_chat_widget.widget_id
    assert_equal job_size + 1, LivechatWorker.jobs.size
    Account.current.products.each do |product|
      assert_present product.chat_widget
    end
  ensure
    unstub_http_request
  end

  def test_enable_failure
    stub_http_request(sucess: false)
    account_wrap do
      post '/livechat/enable'
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal 'error', parsed_response['status']
  ensure
    unstub_http_request
  end

  def test_enable_without_login
    stub_http_request
    reset_request_headers
    account_wrap do
      post '/livechat/enable'
    end
    refute_equal 302, response.status
    refute_equal "http://#{@account.full_domain}/support/login", response.location
  ensure
    unstub_http_request
  end

  # ------------- AGENTS ---------------- #

  def test_agents
    add_agent(Account.current)
    account_wrap do
      get '/livechat/agents'
    end
    assert_response 200
    match_json('agents' => agent_response)
  end

  def test_agents_without_login
    reset_request_headers
    account_wrap do
      get '/livechat/agents'
    end
    assert_response 302
    assert_equal "http://#{@account.full_domain}/support/login", response.location
  end
  # ------------- ADD note ---------------- #

  def test_add_note_with_responder_id_nil
    ticket = create_ticket
    params = { ticket_id: ticket.display_id, note: '<div> Hi </div>' }
    account_wrap do
      post 'livechat/add_note', params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal true, parsed_response['status']
    assert_equal ticket.display_id, parsed_response['external_id']
    assert_equal params[:note], ticket.notes.last.body_html
    assert_equal User.current.id, ticket.reload.responder_id
  end

  def test_add_note_with_update_agent_true
    chat_owner = add_agent(Account.current)
    ticket = create_ticket(responder_id: chat_owner.id)
    params = { ticket_id: ticket.display_id, note: '<div> Hi </div>', updateAgent: 'true' }
    account_wrap do
      post 'livechat/add_note', params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal true, parsed_response['status']
    assert_equal ticket.display_id, parsed_response['external_id']
    assert_equal params[:note], ticket.notes.last.body_html
    assert_equal User.current.id, ticket.reload.responder_id
  end

  def test_add_note_with_chat_owner_id
    ticket = create_ticket(responder_id: @agent.id)
    chat_owner = add_agent(Account.current)
    params = { ticket_id: ticket.display_id, note: '<div> Hi </div>', updateAgent: 'true', chatOwnerId: chat_owner.id }
    account_wrap do
      post 'livechat/add_note', params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal true, parsed_response['status']
    assert_equal ticket.display_id, parsed_response['external_id']
    assert_equal params[:note], ticket.notes.last.body_html
    assert_equal chat_owner.id, ticket.reload.responder_id
  end

  def test_add_note_fails
    Helpdesk::Note.any_instance.stubs(:save_note).returns(false)
    ticket = create_ticket(responder_id: @agent.id)
    chat_owner = add_agent(Account.current)
    account_wrap do
      post 'livechat/add_note', ticket_id: ticket.display_id, note: '<div> Hi </div>', updateAgent: 'true', chatOwnerId: chat_owner.id
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal ticket.display_id, parsed_response['external_id']
    refute false, parsed_response['status']
  ensure
    Helpdesk::Note.any_instance.unstub(:save_note)
  end

  def test_add_note_without_login
    reset_request_headers
    ticket = create_ticket
    params = { ticket_id: ticket.display_id, note: '<div> Hi </div>' }
    account_wrap do
      post 'livechat/add_note', params
    end
    assert_response 302
    assert_equal "http://#{@account.full_domain}/support/login", response.location
  end

  # ------------- CREATE TICKET ---------------- #

  def test_create_ticket
    Account.current.add_feature(:chat)
    widget = create_chat_widget
    params = create_ticket_params(widget_id: widget.id, agent_id: User.current.id)
    account_wrap do
      post 'livechat/create_ticket', params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal true, parsed_response['status']
    assert_present parsed_response['external_id']
    ticket_created = Account.current.tickets.find_by_display_id(parsed_response['external_id'])
    assert_equal Helpdesk::Source::CHAT, ticket_created.source
    assert_equal params[:ticket][:agent_id], ticket_created.responder_id
    meta_note = ticket_created.notes.try(:first)
    assert_present meta_note
    assert_equal @account.helpdesk_sources.note_source_keys_by_token['meta'], meta_note.source
  end

  def test_create_ticket_without_meta
    Account.current.add_feature(:chat)
    widget = create_chat_widget
    params = create_ticket_params(widget_id: widget.id, agent_id: User.current.id)
    params[:ticket].delete(:meta)
    account_wrap do
      post 'livechat/create_ticket', params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal true, parsed_response['status']
    assert_present parsed_response['external_id']
    ticket_created = Account.current.tickets.find_by_display_id(parsed_response['external_id'])
    assert_equal Helpdesk::Source::CHAT, ticket_created.source
    assert_equal params[:ticket][:agent_id], ticket_created.responder_id
    meta_note = ticket_created.notes.try(:first)
    assert_present meta_note
  end

  def test_create_ticket_with_email_not_permissible
    Account.any_instance.stubs(:restricted_helpdesk?).returns(true)
    Account.current.add_feature(:chat)
    widget = create_chat_widget
    account_wrap do
      post 'livechat/create_ticket', create_ticket_params(widget_id: widget.id, agent_id: User.current.id)
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal 'error', parsed_response['status']
    assert_equal 'User email does not belong to a supported domain.', parsed_response['message']
  ensure
    Account.any_instance.unstub(:restricted_helpdesk?)
  end

  def test_create_ticket_with_group_id
    group = create_group(Account.current)
    Account.current.add_feature(:chat)
    widget = create_chat_widget
    params = create_ticket_params(widget_id: widget.id, agent_id: User.current.id, group_id: group.id)
    account_wrap do
      post 'livechat/create_ticket', params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal true, parsed_response['status']
    assert_present parsed_response['external_id']
    ticket_created = Account.current.tickets.find_by_display_id(parsed_response['external_id'])
    assert_equal Helpdesk::Source::CHAT, ticket_created.source
    assert_equal params[:ticket][:agent_id], ticket_created.responder_id
    assert_equal params[:ticket][:group_id], ticket_created.group_id
  end

  def test_create_ticket_with_product
    Account.current.add_feature(:chat)
    widget = create_chat_widget(associate_product: true)
    params = create_ticket_params(widget_id: widget.widget_id, agent_id: User.current.id)
    account_wrap do
      post 'livechat/create_ticket', params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal true, parsed_response['status']
    assert_present parsed_response['external_id']
    ticket_created = Account.current.tickets.find_by_display_id(parsed_response['external_id'])
    assert_equal Helpdesk::Source::CHAT, ticket_created.source
    assert_equal params[:ticket][:agent_id], ticket_created.responder_id
    assert_equal widget.product_id, ticket_created.product_id
  end

  def test_create_ticket_without_login
    Account.current.add_feature(:chat)
    widget = create_chat_widget
    params = create_ticket_params(widget_id: widget.id, agent_id: User.current.id)
    reset_request_headers
    account_wrap do
      post 'livechat/create_ticket', params
    end
    assert_response 302
    assert_equal "http://#{@account.full_domain}/support/login", response.location
  end

  private

    def old_ui?
      true
    end

    def stub_http_request(sucess: true, add_url: nil, status: 503)
      agent_link_response = { sucess: sucess }
      response_text = { 'data' => { 'site' => { 'site_id' => '100' }, 'widget' => { 'widget_id' => '200' } } }
      response_text['data'].merge!('url' => add_url) if add_url.present?
      agent_link_response.stubs(:body).returns(response_text.to_json)
      agent_link_response.stubs(:code).returns(sucess ? 200 : status)
      agent_link_response.stubs(:message).returns(sucess ? 'Success' : 'Failure')
      agent_link_response.stubs(:headers).returns({})
      HTTParty::Request.any_instance.stubs(:perform).returns(agent_link_response)
      response_text
    end

    def unstub_http_request
      HTTParty::Request.any_instance.unstub(:perform)
    end

    def agent_response
      Account.current.agents_from_cache.collect { |c| { name: c.user.name, id: c.user.id } }.to_json
    end

    def groups_response
      groups = []
      groups.push([I18n.t('livechat.everyone'), 0])
      groups.concat(Account.current.groups.collect { |c| [c.name, c.id] }).to_json
      groups.to_json
    end

    def response_hash(code: 'success', status: 200, site_id: '100', widget_id: '200')
      {
        code: code,
        status: status,
        data: {
          site: {
            site_id: site_id
          },
          widget: {
            widget_id: widget_id
          }
        }
      }
    end

    def create_ticket(responder_id: nil)
      ticket = Account.current.tickets.new(requester_id: @agent.id, subject: Faker::Lorem.words(3), responder_id: responder_id)
      ticket.save
      ticket
    end
end
