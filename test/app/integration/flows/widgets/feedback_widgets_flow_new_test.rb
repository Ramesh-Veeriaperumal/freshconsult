require_relative '../../../../api/api_test_helper'
require_relative '../../../../core/helpers/users_test_helper'
require_relative '../../../../core/helpers/controller_test_helper'
require_relative '../../../../core/helpers/tickets_test_helper'

class Widgets::FeedbackWidgetsFlowTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper
  include CoreTicketsTestHelper
  include CoreUsersTestHelper
  include ProductsHelper
  include Redis::OthersRedis

  # ------------------------------ #create ----------------------- #

  def test_create_with_wrong_ticket_type
    ticket_type_field = Account.current.ticket_fields.where(name: 'ticket_type')
    toggle_editable_in_portal(ticket_type_field)
    params = construct_params(version: 'v2', helpdesk_ticket: { email: @agent.email, ticket_type: "Question<svg/onload=alert('XSS')>" })
    account_wrap do
      post '/widgets/feedback_widget', params
    end
    assert_response 200
    error_response = JSON.parse(response.body)
    assert_equal error_response['success'], false
    assert_equal error_response['error'], 'Invalid ticket type'
  end

  def test_create_with_correct_ticket_type
    ticket_type_field = Account.current.ticket_fields.where(name: 'ticket_type')
    toggle_editable_in_portal(ticket_type_field)
    params = { helpdesk_ticket: { email: @agent.email, ticket_type: 'Question' } }
    account_wrap do
      post '/widgets/feedback_widget', params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert parsed_response['success']
    assert_equal 'Question', @agent.tickets.last.ticket_type
  end

  def test_create_with_empty_ticket_type
    ticket_type_field = Account.current.ticket_fields.where(name: 'ticket_type')
    toggle_editable_in_portal(ticket_type_field)
    params = { helpdesk_ticket: { email: @agent.email, ticket_type: '' } }
    account_wrap do
      post '/widgets/feedback_widget', params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert parsed_response['success']
    assert_nil @agent.tickets.last.ticket_type
  end

  def test_create_with_nil_ticket_type
    ticket_type_field = Account.current.ticket_fields.where(name: 'ticket_type').first
    ticket_type_field.editable_in_portal = true
    ticket_type_field.save
    params = { helpdesk_ticket: { email: @agent.email, ticket_type: nil } }
    account_wrap do
      post '/widgets/feedback_widget', params
    end
    assert_response 200
    assert JSON.parse(response.body)['success']
  end

  def test_create_with_captcha_true
    Account.any_instance.stubs(:feedback_widget_captcha_allowed?).returns(true)
    Widgets::FeedbackWidgetsController.any_instance.stubs(:verify_recaptcha).returns(false)
    Widgets::FeedbackWidgetsController.any_instance.stubs(:current_user).returns(nil)
    retain_params = { widgetType: 'popup' }.to_json
    params = { helpdesk_ticket: { email: 'abc@gmail.com', ticket_type: 'Question' }, widgetType: 'popup', retainParams: retain_params }
    account_wrap do
      post '/widgets/feedback_widget', params
    end
    assert_response 200
    refute JSON.parse(response.body)['success']
  ensure
    Account.any_instance.unstub(:feedback_widget_captcha_allowed?)
    Widgets::FeedbackWidgetsController.any_instance.unstub(:verify_recaptcha)
    Widgets::FeedbackWidgetsController.any_instance.unstub(:current_user)
  end

  def test_create_from_account_with_ehawk_spam_4_and_above
    Account.any_instance.stubs(:ehawk_spam?).returns(true)
    params = { helpdesk_ticket: { email: @agent.email } }
    account_wrap do
      post '/widgets/feedback_widget', params
    end
    assert_response 403
    error_response = JSON.parse(response.body)
    assert_equal error_response['success'], false
    assert_equal error_response['error'], 'You have been restricted from creating a ticket.'
  ensure
    Account.any_instance.unstub(:ehawk_spam?)
  end

  def test_ticket_create_with_meta
    meta = { 'user_agent' => 'Mozilla Mac OS', 'referrer' => 'https://localhost.freshdesk.com' }
    params = { helpdesk_ticket: { email: @agent.email }, meta: meta }
    account_wrap do
      post '/widgets/feedback_widget', params
    end
    assert_response 200
    assert JSON.parse(response.body)['success']
    meta_note = Account.current.tickets.last.notes.last
    assert_equal meta_note.source, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN_1['meta']
    parsed_meta_body = YAML.safe_load(meta_note.note_body.body)
    assert_equal meta['user_agent'], parsed_meta_body['user_agent']
    assert_equal meta['referrer'], parsed_meta_body['referrer']
  end

  def test_ticket_create_with_referrer_sanitize_exception
    meta = { 'user_agent' => 'Mozilla Mac OS', 'referrer' => "'http://bit.ly/VQgHKj'" }
    params = { helpdesk_ticket: { email: @agent.email }, meta: meta }
    account_wrap do
      post '/widgets/feedback_widget', params
    end
    assert_response 200
    assert JSON.parse(response.body)['success']
    meta_note = Account.current.tickets.last.notes.last
    assert_equal meta_note.source, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN_1['meta']
    parsed_meta_body = YAML.safe_load(meta_note.note_body.body)
    assert_equal meta['user_agent'], parsed_meta_body['user_agent']
    assert_nil parsed_meta_body['referrer']
  end

  def test_ticket_create_with_support_ticket_limit_redis_key_absent
    Account.any_instance.stubs(:redis_key_exists?).returns(false)
    params = { helpdesk_ticket: { email: 'padmashir@fgma.com' }, meta: { user_agent: 'Mozilla Mac OS', referrer: 'https://localhost.freshdesk.com' } }
    User.any_instance.stubs(:customer?).returns(true)
    account_wrap do
      post '/widgets/feedback_widget', params
    end
    assert_response 200
    assert JSON.parse(response.body)['success']
    support_ticket_limit = format(SUPPORT_TICKET_LIMIT, account_id: Account.current.id, user_id: User.current.id)
    redis_value = get_others_redis_key(support_ticket_limit)
    assert_equal '1', redis_value
  ensure
    Account.any_instance.unstub(:redis_key_exists?)
    User.any_instance.unstub(:customer?)
  end

  def test_ticket_create_with_support_ticket_limit_redis_key_increment
    Account.any_instance.stubs(:redis_key_exists?).returns(true)
    @agent.make_current
    User.any_instance.stubs(:customer?).returns(true)
    support_ticket_limit = format(SUPPORT_TICKET_LIMIT, account_id: Account.current.id, user_id: User.current.id)
    set_others_redis_key(support_ticket_limit, 25)
    params = { helpdesk_ticket: { email: @agent.email }, meta: { user_agent: 'Mozilla Mac OS', referrer: 'https://localhost.freshdesk.com' } }
    account_wrap do
      post '/widgets/feedback_widget', params
    end
    assert_response 200
    assert JSON.parse(response.body)['success']
    redis_value = get_others_redis_key(support_ticket_limit)
    assert_equal '26', redis_value
  ensure
    Account.any_instance.unstub(:redis_key_exists?)
    User.any_instance.unstub(:customer?)
    User.reset_current_user
  end

  def test_ticket_create_without_current_user_and_without_permission
    Account.any_instance.stubs(:restricted_helpdesk?).returns(true)
    Widgets::FeedbackWidgetsController.any_instance.stubs(:current_user).returns(nil)
    params = { helpdesk_ticket: { email: 'abc.hjl@gpmail.com' } }
    account_wrap do
      post '/widgets/feedback_widget', params
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    refute parsed_response['success']
    assert_equal 'Invalid Requester', parsed_response['error']
  ensure
    Account.any_instance.unstub(:restricted_helpdesk?)
    Widgets::FeedbackWidgetsController.any_instance.unstub(:current_user)
  end

  def test_ticket_create_with_cc
    cc_email_list = ['abc@gmail.com']
    params = { helpdesk_ticket: { email: @agent.email }, cc_emails: cc_email_list }
    account_wrap do
      post '/widgets/feedback_widget', params
    end
    assert_response 200
    assert JSON.parse(response.body)['success']
    ticket = @agent.tickets.last
    cc_emails = ticket.cc_email
    assert_equal cc_email_list, cc_emails[:cc_emails]
    assert_equal cc_email_list, cc_emails[:tkt_cc]
    assert_equal cc_email_list, cc_emails[:reply_cc]
    assert_empty cc_emails[:fwd_emails]
    assert_empty cc_emails[:bcc_emails]
    assert_equal 2, ticket.status
    assert Delayed::Job.last.handler.include?('send_cc_email')
  end

  def test_ticket_create_auto_email_assignment
    retain_params = { widgetType: 'popup' }.to_json
    Account.current.add_feature(:anonymous_tickets)
    params = { helpdesk_ticket: { ticket_type: 'Question' }, retainParams: retain_params }
    account_wrap do
      post '/widgets/feedback_widget', params
    end
    assert_response 200
    assert JSON.parse(response.body)['success']
    assert_equal @agent.email, Account.current.tickets.last.requester.email
  end

  def test_ticket_create_current_user_email_overridding
    Account.current.add_feature(:anonymous_tickets)
    email = 'lpo@hyu.com'
    params = { helpdesk_ticket: { email: email } }
    account_wrap do
      post '/widgets/feedback_widget', params
    end
    assert_response 200
    assert JSON.parse(response.body)['success']
    assert_equal email, Account.current.tickets.last.requester.email
  end

  def test_ticket_create_with_status
    ticket_type_field = Account.current.ticket_fields.where(name: 'status')
    toggle_editable_in_portal(ticket_type_field)
    params = { helpdesk_ticket: { email: @agent.email, status: 4 } }
    account_wrap do
      post '/widgets/feedback_widget', params
    end
    assert_response 200
    assert JSON.parse(response.body)['success']
    assert_equal 4, @agent.tickets.last.status
  end

  def test_create_with_callback
    params = { helpdesk_ticket: { email: @agent.email, ticket_type: 'Question' }, callback: 'open' }
    account_wrap do
      post '/widgets/feedback_widget', params
    end
    assert_response 200
    expected_json_callback_data = { success: true }.to_json
    assert_equal response.body, "open(#{expected_json_callback_data})"
  end

  # ------------------------------ #jsonp_create ----------------------- #

  def test_jsonp_create_with_callback
    params = { helpdesk_ticket: { email: @agent.email, ticket_type: 'Question' }, callback: 'open' }
    account_wrap do
      get '/widgets/feedback_widget/jsonp_create', params
    end
    assert_response 200
    expected_json_callback_data = { success: true }.to_json
    assert_equal response.body, "open(#{expected_json_callback_data})"
  end

  def test_jsonp_create_with_captcha_true
    Account.any_instance.stubs(:feedback_widget_captcha_allowed?).returns(true)
    Widgets::FeedbackWidgetsController.any_instance.stubs(:verify_recaptcha).returns(false)
    retain_params = { widgetType: 'popup' }.to_json
    params = { helpdesk_ticket: { email: 'abc@gmail.com', ticket_type: 'Question' }, widgetType: 'popup', retainParams: retain_params, check_captcha: 'true' }
    account_wrap do
      get '/widgets/feedback_widget/jsonp_create', params
    end
    assert_response 200
    refute JSON.parse(response.body)['success']
  ensure
    Account.any_instance.unstub(:feedback_widget_captcha_allowed?)
    Widgets::FeedbackWidgetsController.any_instance.unstub(:verify_recaptcha)
  end

  def test_ticket_jsonp_create_with_meta
    meta = { 'user_agent' => 'Mozilla Mac OS', 'referrer' => 'https://localhost.freshdesk.com' }
    params = { helpdesk_ticket: { email: @agent.email, ticket_type: 'Question' }, meta: meta }
    account_wrap do
      get '/widgets/feedback_widget/jsonp_create', params
    end
    assert_response 200
    assert JSON.parse(response.body)['success']
    meta_note = Account.current.tickets.last.notes.last
    assert_equal meta_note.source, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN_1['meta']
    parsed_meta_body = YAML.safe_load(meta_note.note_body.body)
    assert_equal meta['user_agent'], parsed_meta_body['user_agent']
    assert_equal meta['referrer'], parsed_meta_body['referrer']
  end

  def test_ticket_jsonp_create_with_cc
    cc_email_list = ['abc@gmail.com']
    params = { helpdesk_ticket: { email: @agent.email, ticket_type: 'Question' }, cc_emails: cc_email_list }
    account_wrap do
      get '/widgets/feedback_widget/jsonp_create', params
    end
    assert_response 200
    assert JSON.parse(response.body)['success']
    cc_emails = @agent.tickets.last.cc_email
    assert_equal cc_email_list, cc_emails[:cc_emails]
    assert_equal cc_email_list, cc_emails[:tkt_cc]
    assert_equal cc_email_list, cc_emails[:reply_cc]
    assert_empty cc_emails[:fwd_emails]
    assert_empty cc_emails[:bcc_emails]
  end

  def test_ticket_jsonp_create_with_status
    params = { helpdesk_ticket: { email: @agent.email, ticket_type: 'Question', status: 4 } }
    account_wrap do
      get '/widgets/feedback_widget/jsonp_create', params
    end
    assert_response 200
    assert JSON.parse(response.body)['success']
    assert_equal 4, @agent.tickets.last.status
  end

  # ------------------------------ #new  --------------------------------- #

  def test_new
    account_wrap do
      get '/widgets/feedback_widget/new'
    end
    assert_response 200
    assert_template :new
  end

  # ------------------------------ #thanks --------------------------------- #

  def test_thank_you
    retain_params = { widgetType: 'popup' }.to_json
    account_wrap do
      get '/widgets/feedback_widget/thanks', retainParams: retain_params
    end
    assert_response 200
    assert_template :thanks
  end

  private

    def toggle_editable_in_portal(fields)
      fields.each do |field|
        field.visible_in_portal = true
        field.editable_in_portal = true
        field.save
      end
    end

    def old_ui?
      true
    end
end
