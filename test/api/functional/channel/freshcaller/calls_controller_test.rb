require_relative '../../../test_helper'
class Channel::Freshcaller::CallsControllerTest < ActionController::TestCase
  include Freshcaller::CallsTestHelper
  include ConversationsTestHelper
  include ::Freshcaller::JwtAuthentication
  include ApiTicketsTestHelper

  def setup
    super
    initial_setup
  end

  def teardown
    super
    @account.reload
    @account.revoke_feature(:freshcaller)
    CustomRequestStore.store[:private_api_request] = @initial_private_api_request
  end

  @initial_setup_run = false

  def initial_setup
    @initial_private_api_request = CustomRequestStore.store[:private_api_request]
    CustomRequestStore.store[:private_api_request] = true
    @account.reload
    return if @initial_setup_run
    @account.add_feature(:freshcaller)
    ::Freshcaller::Account.new(account_id: @account.id).save
    @account.reload
    @account.save
    @initial_setup_run = true
  end

  def test_create_with_invalid_auth
    invalid_auth_header
    assert_create_unauthorized
  end

  def test_update_with_invalid_auth
    invalid_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(version: 'channel', id: call_id, recording_status: Freshcaller::Call::RECORDING_STATUS_HASH[:'in-progress'])
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:unauthorized]
  end

  def test_update_before_create_with_invalid_auth
    invalid_auth_header
    call_id = get_call_id
    put :update, construct_params(version: 'channel', id: call_id, recording_status: Freshcaller::Call::RECORDING_STATUS_HASH[:'in-progress'])
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:unauthorized]
  end

  def test_create_with_valid_params_and_basic_auth
    set_basic_auth_header
    assert_create
  end

  def test_update_recording_status_and_basic_auth
    set_basic_auth_header
    assert_update
  end

  def test_update_recording_status_and_basic_auth_with_out_create
    set_basic_auth_header
    call_id = get_call_id
    put :update, construct_params(version: 'channel', id: call_id, recording_status: 1)
    call = ::Freshcaller::Call.last
    match_json(create_pattern(call))
    assert_equal 1, call.recording_status
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  end

  def test_create_with_valid_params
    set_auth_header
    assert_create
  end

  def test_create_with_valid_params_with_agent
    auth_header_with_agent_email
    assert_create
  end

  def test_create_with_valid_params_with_contact
    auth_header_with_contact_key
    assert_create_unauthorized
  end

  def test_create_with_update_field
    set_auth_header
    post :create, construct_params(version: 'channel', fc_call_id: get_call_id, ticket_display_id: 1)
    match_json([bad_request_error_pattern('ticket_display_id', :invalid_field)])
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:bad_request]
  end

  def test_create_with_empty_params
    set_auth_header
    post :create, construct_params(version: 'channel')
    match_json([bad_request_error_pattern('fc_call_id', :missing_field)])
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:bad_request]
  end

  def test_update_recording_status
    set_auth_header
    assert_update
  end

  def test_update_recording_status_with_agent
    auth_header_with_agent_email
    assert_update
  end

  def test_update_recording_status_with_contact
    auth_header_with_contact_key
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(version: 'channel', id: call_id, recording_status: 1)
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:unauthorized]
  end

  def test_update_with_missed_call_params
    set_auth_header
    assert_voice_mail_missed_call('no-answer')
  end

  def test_update_with_missed_call_params_with_agent
    auth_header_with_agent_email
    assert_voice_mail_missed_call('no-answer')
  end

  def test_update_with_missed_call_params_with_contact
    auth_header_with_contact_key
    assert_voicemail_missed_call_unauthorized('no-answer')
  end

  def test_update_with_default_call_status_params
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(convert_call_params(call_id, 'default'))
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(ticket_only_pattern(call))
    assert_equal call.notable.description.present?, true # for default call status, the call will be directly assocaited to ticket
    assert_equal call.notable.description_html.present?, true
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  end

  def test_update_with_voicemail_params
    set_auth_header
    assert_voice_mail_missed_call('voicemail')
  end

  def test_update_with_voicemail_params_with_agent
    auth_header_with_agent_email
    assert_voice_mail_missed_call('voicemail')
  end

  def test_update_with_voicemail_params_with_contact
    auth_header_with_contact_key
    assert_voicemail_missed_call_unauthorized('voicemail')
  end

  def test_update_with_abandoned_params
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(convert_call_params(call_id, 'abandoned'))
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(ticket_only_pattern(call))
    assert_equal call.notable.description.present?, true # for default call status, the call will be directly assocaited to ticket
    assert_equal call.notable.description_html.present?, true
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  end

  def test_update_with_voicemail_abandoned_sceanrio
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(convert_call_params(call_id, 'voicemail'))
    put :update, construct_params(convert_call_params(call_id, 'abandoned'))
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(ticket_with_note_pattern(call))
    assert_equal Helpdesk::Ticket.default_cc_hash, call.notable.notable.cc_email
    assert_equal call.notable.notable.description.present?, true
    assert_equal call.notable.notable.description_html.include?('Abandoned call'), true
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  end

  def test_update_with_callback_abandoned_scenario
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    params = construct_params(convert_call_params(call_id, 'abandoned')).merge!(ancestry: get_call_id, callback: true, call_type: 'outgoing')
    put :update, construct_params(params)
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(ticket_only_pattern(call))
    assert_equal call.notable.description.present?, true
    assert_equal call.notable.description_html.include?('Callback'), true
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  end

  def test_update_with_callback_voicemail_scenario
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    params = construct_params(convert_call_params(call_id, 'voicemail')).merge!(ancestry: get_call_id, callback: true, call_type: 'outgoing')
    put :update, construct_params(params)
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(ticket_with_note_pattern(call))
    assert_equal call.notable.notable.description.present?, true
    assert_equal call.notable.notable.description_html.include?('Voicemail'), true
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  end

  def test_update_with_callback_missed_scenario
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    params = construct_params(convert_call_params(call_id, 'no-answer')).merge!(ancestry: get_call_id, callback: true, call_type: 'outgoing')
    put :update, construct_params(params)
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(ticket_with_note_pattern(call))
    assert_equal call.notable.notable.subject.include?('Missed callback'), true
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  end

  def test_update_with_callback_child_completed_scenario
    ::Freshcaller::Call.destroy_all
    set_auth_header
    call_id = get_call_id
    user = @account.technicians.first
    create_call(fc_call_id: call_id, account_id: @account.id)
    params = convert_call_params(call_id, 'completed').merge(ancestry: get_call_id, callback: true, call_type: 'outgoing')
    put :update, construct_params(params)
    call = ::Freshcaller::Call.where(fc_call_id: call_id).all.first
    call_notable = call.notable.notable
    assert_equal call_notable.description.present?, true
    assert_equal call_notable.description_html.include?('Conversation between'), true
    assert_equal call_notable.subject.include?('Outgoing call'), true
    assert_equal Helpdesk::Ticket.default_cc_hash, call_notable.cc_email
    match_json(ticket_with_note_pattern(call))
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  end

  def test_update_with_callback_parent_missed_scenario
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    params = construct_params(convert_call_params(call_id, 'no-answer')).merge!(ancestry: nil, callback: true)
    put :update, construct_params(params)
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(create_pattern(call))
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  end

  def test_update_with_convert_call_to_ticket_params
    ::Freshcaller::Call.destroy_all
    set_auth_header
    call_id = get_call_id
    user = @account.technicians.first
    create_call(fc_call_id: call_id, account_id: @account.id)
    params = convert_call_params(call_id, 'completed').merge(agent_email: user.email)
    put :update, construct_params(params)
    call = ::Freshcaller::Call.where(fc_call_id: call_id).all.first
    assert_equal user.id, call.notable.notable.responder_id
    assert_equal Helpdesk::Ticket.default_cc_hash, call.notable.notable.cc_email
    match_json(ticket_with_note_pattern(call))
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  end

  def test_update_with_convert_call_to_note_params
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(convert_call_to_note_params(call_id, 'completed'))
    call = Account.current.freshcaller_calls.find_by_fc_call_id(call_id)
    assert call.notable.present?, 'Ticket not linked to call!'
    match_json(ticket_with_note_pattern(call))
    assert_equal Helpdesk::Ticket.default_cc_hash, call.notable.notable.cc_email
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  end

  def test_update_with_convert_call_to_ticket_with_subject_and_description_params
    set_auto_settings(:connected_calls, true)
    ::Freshcaller::Call.destroy_all
    set_auth_header
    call_id = get_call_id
    user = @account.technicians.first
    create_call(fc_call_id: call_id, account_id: @account.id)
    subject = 'Call with Test and +919789814486'
    description = 'Call description'
    params = convert_call_params(call_id, 'completed').merge(agent_email: user.email, subject: subject, description: description)
    put :update, construct_params(params)
    call = ::Freshcaller::Call.where(fc_call_id: call_id).all.first
    call_notable = call.notable.notable
    assert_equal user.id, call_notable.responder_id
    assert_equal subject, call_notable.subject
    assert_equal description, call_notable.description
    assert_equal Helpdesk::Ticket.default_cc_hash, call.notable.notable.cc_email
    match_json(ticket_with_note_pattern(call))
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    set_auto_settings_to_default
    call&.destroy
  end

  def test_update_with_convert_inprogress_call_to_note_params
    set_auth_header
    set_auto_settings(:connected_calls, true)
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(call_note_params(call_id, 'in-progress'))
    call = ::Freshcaller::Call.last
    match_json(ticket_with_note_pattern(call))
    assert_equal Helpdesk::Ticket.default_cc_hash, call.notable.notable.cc_email
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    set_auto_settings_to_default
    call&.destroy
  end

  def test_update_with_invalid_params
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(update_invalid_params(call_id))
    match_json([bad_request_error_pattern(:call_status, :not_included, list: 'voicemail,no-answer,completed,in-progress,on-hold,default,abandoned'),
                bad_request_error_pattern(:call_created_at, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                bad_request_error_pattern(:customer_number, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                bad_request_error_pattern(:agent_number, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                bad_request_error_pattern(:customer_location, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                bad_request_error_pattern(:duration, :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern(:note, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                bad_request_error_pattern(:ticket_display_id, :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                bad_request_error_pattern(:agent_email, :invalid_format, accepted: 'valid email address')])
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:bad_request]
  end

  def test_update_without_fc_call_id
    set_auth_header
    put :update, construct_params(version: 'channel', id: '', recording_status: 1)
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:not_found]
  end

  def test_update_with_convert_call_to_note_with_existing_ticket_with_create_ticket_revamp
    Account.current.launch :freshcaller_ticket_revamp
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(convert_call_to_note_params(call_id, 'completed'))
    call = ::Freshcaller::Call.last
    sec_ticket = call.associated_ticket
    set_auth_header
    put :update, construct_params(convert_call_to_note_params(call_id, 'completed'))
    call.reload
    match_json(ticket_with_note_pattern(call))
    prim_ticket = call.associated_ticket
    assert sec_ticket.parent_ticket == prim_ticket.id
    call.destroy
    prim_ticket.destroy
    sec_ticket.destroy
  ensure
    Account.current.rollback :freshcaller_ticket_revamp
  end

  # Update without auto ticket creation

  def test_update_with_missed_call_params_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:missed_calls, false)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(convert_incoming_call_params(call_id, 'no-answer'))
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(create_pattern(call))
    assert call.call_info.present?
    assert call.call_info[:description].present?
    assert call.notable.blank?
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
    call&.destroy
  end

  def test_update_with_missed_call_params_with_agent_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:missed_calls, false)
    auth_header_with_agent_email
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(convert_incoming_call_params(call_id, 'no-answer'))
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(create_pattern(call))
    assert call.call_info.present?
    assert call.call_info[:description].present?
    assert call.notable.blank?
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
    call&.destroy
  end

  def test_update_with_missed_call_params_with_contact_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    auth_header_with_contact_key
    assert_voicemail_missed_call_unauthorized('no-answer')
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
  end

  def test_update_with_default_call_status_params_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(convert_call_params(call_id, 'default'))
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(create_pattern(call))
    assert call.call_info.present?
    assert call.call_info[:description].present?
    assert call.notable.blank?
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    call&.destroy
  end

  def test_update_with_voicemail_params_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:missed_calls, false)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(convert_incoming_call_params(call_id, 'voicemail'))
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(create_pattern(call))
    assert call.call_info.present?
    assert call.call_info[:description].present?
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
    call&.destroy
  end

  def test_update_with_voicemail_params_with_agent_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:missed_calls, false)
    auth_header_with_agent_email
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(convert_incoming_call_params(call_id, 'voicemail'))
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(create_pattern(call))
    assert call.call_info.present?
    assert call.call_info[:description].present?
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
    call&.destroy
  end

  def test_update_with_abandoned_params_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:abandoned_calls, false)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(convert_call_params(call_id, 'abandoned'))
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(create_pattern(call))
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
    call&.destroy
  end

  def test_update_with_voicemail_abandoned_sceanrio_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:abandoned_calls, false)
    set_auto_settings(:missed_calls, false)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(convert_call_params(call_id, 'voicemail'))
    put :update, construct_params(convert_call_params(call_id, 'abandoned'))
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(create_pattern(call))
    assert call.call_info.present?
    assert call.call_info[:description].present?
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
    call&.destroy
  end

  def test_update_with_callback_abandoned_scenario_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:abandoned_calls, false)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    params = construct_params(convert_call_params(call_id, 'abandoned')).merge!(ancestry: get_call_id, callback: true, call_type: 'outgoing')
    put :update, construct_params(params)
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(create_pattern(call))
    assert call.call_info.present?
    assert call.call_info[:description].present?
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end

  def test_update_with_callback_voicemail_scenario_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:missed_calls, false)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    params = construct_params(convert_call_params(call_id, 'voicemail')).merge!(ancestry: get_call_id, callback: true, call_type: 'outgoing')
    put :update, construct_params(params)
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(create_pattern(call))
    assert call.call_info.present?
    assert call.call_info[:description].present?
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end

  def test_update_with_callback_missed_scenario_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:missed_calls, false)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    params = construct_params(convert_call_params(call_id, 'no-answer')).merge!(ancestry: get_call_id, callback: true, call_type: 'outgoing')
    put :update, construct_params(params)
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(create_pattern(call))
    assert call.call_info.present?
    assert call.call_info[:description].present?
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end

  def test_update_with_callback_child_completed_scenario_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:connected_calls, false)
    ::Freshcaller::Call.destroy_all
    set_auth_header
    call_id = get_call_id
    user = @account.technicians.first
    create_call(fc_call_id: call_id, account_id: @account.id)
    params = convert_call_params(call_id, 'completed').merge(ancestry: get_call_id, callback: true, call_type: 'outgoing')
    put :update, construct_params(params)
    call = ::Freshcaller::Call.where(fc_call_id: call_id).all.first
    match_json(create_pattern(call))
    assert call.call_info.present?
    assert call.call_info[:description].present?
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end

  def test_update_with_callback_parent_missed_scenario_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:missed_calls, false)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    params = construct_params(convert_call_params(call_id, 'no-answer')).merge!(ancestry: nil, callback: true)
    put :update, construct_params(params)
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(create_pattern(call))
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
    call&.destroy
  end

  def test_update_with_convert_call_to_ticket_params_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:connected_calls, false)
    ::Freshcaller::Call.destroy_all
    set_auth_header
    call_id = get_call_id
    user = @account.technicians.first
    create_call(fc_call_id: call_id, account_id: @account.id)
    params = convert_call_params(call_id, 'completed').merge(agent_email: user.email)
    put :update, construct_params(params)
    call = ::Freshcaller::Call.where(fc_call_id: call_id).all.first
    match_json(create_pattern(call))
    assert call.call_info.present?
    assert call.call_info[:description].present?
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
    call&.destroy
  end

  def test_update_with_subject_and_description_params_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:connected_calls, false)
    ::Freshcaller::Call.destroy_all
    set_auth_header
    call_id = get_call_id
    user = @account.technicians.first
    create_call(fc_call_id: call_id, account_id: @account.id)
    subject = 'Call with Test and +919789814486'
    description = 'Call description'
    params = convert_call_params(call_id, 'completed').merge(agent_email: user.email, subject: subject, description: description)
    put :update, construct_params(params)
    call = ::Freshcaller::Call.where(fc_call_id: call_id).all.first
    match_json(create_pattern(call))
    assert call.call_info.present?
    assert call.call_info[:description].present?
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
    call&.destroy
  end

  def test_update_with_convert_call_to_note_params_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(convert_call_to_note_params(call_id, 'completed'))
    call = Account.current.freshcaller_calls.find_by_fc_call_id(call_id)
    assert call.notable.present?, 'Ticket not linked to call!'
    match_json(ticket_with_note_pattern(call))
    assert call.call_info.present?
    assert call.call_info[:description].present?
    assert_equal Helpdesk::Ticket.default_cc_hash, call.notable.notable.cc_email
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
    call&.destroy
  end

  def test_update_with_ticket_already_linked_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:connected_calls, false)
    set_auth_header
    call_id = get_call_id
    user = @account.technicians.first
    create_call(fc_call_id: call_id)
    call = ::Freshcaller::Call.last
    ticket = create_ticket
    call.notable = ticket
    call.save
    put :update, construct_params(convert_call_params(call_id, 'completed').merge(agent_email: user.email))
    call.reload
    match_json(ticket_with_note_pattern(call))
    assert call.call_info.present?
    assert call.call_info[:description].present?
    assert ticket.notes.conversations.where(id: call.notable_id).present?, 'Note not linked to call!'
    assert_equal Helpdesk::Ticket.default_cc_hash, call.notable.notable.cc_email
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
    call&.destroy
  end

  def test_update_with_note_already_linked_without_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:connected_calls, false)
    set_auth_header
    call_id = get_call_id
    user = @account.technicians.first
    create_call(fc_call_id: call_id)
    call = ::Freshcaller::Call.last
    ticket = create_ticket
    note = create_note(custom_note_params(ticket, Account.current.helpdesk_sources.note_source_keys_by_token[:note]))
    call.notable = note
    call.save
    put :update, construct_params(convert_call_params(call_id, 'completed').merge(agent_email: user.email))
    call.reload
    match_json(ticket_with_note_pattern(call))
    assert call.call_info.present?
    assert call.call_info[:description].present?
    assert ticket.notes.conversations.where(id: call.notable_id).present?, 'Note not linked to call!'
    assert_equal Helpdesk::Ticket.default_cc_hash, call.notable.notable.cc_email
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
    call&.destroy
  end

  # Update with auto ticket creation

  def test_update_with_missed_call_params_with_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auth_header
    set_auto_settings(:missed_calls, true)
    assert_voice_mail_missed_call('no-answer')
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end

  def test_update_with_missed_call_params_with_agent_with_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    auth_header_with_agent_email
    set_auto_settings(:missed_calls, true)
    assert_voice_mail_missed_call('no-answer')
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end

  def test_update_with_missed_call_params_with_contact_with_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    auth_header_with_contact_key
    set_auto_settings(:missed_calls, true)
    assert_voicemail_missed_call_unauthorized('no-answer')
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end

  def test_update_with_default_call_status_params_with_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:connected_calls, true)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(convert_call_params(call_id, 'default'))
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(ticket_with_note_pattern(call))
    assert_equal call.notable.notable.description.present?, true # for default call status, the call will be directly assocaited to ticket
    assert_equal call.notable.notable.description_html.present?, true
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end

  def test_update_with_voicemail_params_with_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:missed_calls, true)
    set_auth_header
    assert_voice_mail_missed_call('voicemail')
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end

  def test_update_with_voicemail_params_with_agent_with_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:missed_calls, true)
    auth_header_with_agent_email
    assert_voice_mail_missed_call('voicemail')
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end

  def test_update_with_abandoned_params_with_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:abandoned_calls, true)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(convert_call_params(call_id, 'abandoned'))
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(ticket_only_pattern(call))
    assert_equal call.notable.description.present?, true
    assert_equal call.notable.description_html.present?, true
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end

  def test_update_with_voicemail_abandoned_sceanrio_with_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:abandoned_calls, true)
    set_auto_settings(:missed_calls, true)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    put :update, construct_params(convert_call_params(call_id, 'voicemail'))
    put :update, construct_params(convert_call_params(call_id, 'abandoned'))
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(ticket_with_note_pattern(call))
    assert_equal Helpdesk::Ticket.default_cc_hash, call.notable.notable.cc_email
    assert_equal call.notable.notable.description.present?, true
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end

  def test_update_with_callback_abandoned_scenario_with_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:abandoned_calls, true)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    params = construct_params(convert_call_params(call_id, 'abandoned')).merge!(ancestry: get_call_id, callback: true, call_type: 'outgoing')
    put :update, construct_params(params)
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(ticket_only_pattern(call))
    assert_equal call.notable.description.present?, true
    assert_equal call.notable.description_html.include?('Callback'), true
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end

  def test_update_with_callback_voicemail_scenario_with_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:missed_calls, true)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    params = construct_params(convert_call_params(call_id, 'voicemail')).merge!(ancestry: get_call_id, callback: true, call_type: 'outgoing')
    put :update, construct_params(params)
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(ticket_with_note_pattern(call))
    assert_equal call.notable.notable.description.present?, true
    assert_equal call.notable.notable.description_html.include?('Voicemail'), true
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end

  def test_update_with_callback_missed_scenario_with_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:missed_calls, true)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    params = construct_params(convert_call_params(call_id, 'no-answer')).merge!(ancestry: get_call_id, callback: true, call_type: 'outgoing')
    put :update, construct_params(params)
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(ticket_with_note_pattern(call))
    assert_equal call.notable.notable.subject.include?('Missed callback'), true
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end

  def test_update_with_callback_child_completed_scenario_with_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:connected_calls, true)
    ::Freshcaller::Call.destroy_all
    set_auth_header
    call_id = get_call_id
    user = @account.technicians.first
    create_call(fc_call_id: call_id, account_id: @account.id)
    params = convert_call_params(call_id, 'completed').merge(ancestry: get_call_id, callback: true, call_type: 'outgoing')
    put :update, construct_params(params)
    call = ::Freshcaller::Call.where(fc_call_id: call_id).all.first
    call_notable = call.notable.notable
    assert_equal call_notable.description.present?, true
    assert_equal call_notable.description_html.include?('Conversation between'), true
    assert_equal call_notable.subject.include?('Outgoing call'), true
    assert_equal Helpdesk::Ticket.default_cc_hash, call_notable.cc_email
    match_json(ticket_with_note_pattern(call))
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end

  def test_update_with_callback_parent_missed_scenario_with_auto_creation
    Account.current.launch(:freshcaller_ticket_revamp)
    set_auto_settings(:missed_calls, true)
    set_auth_header
    call_id = get_call_id
    create_call(fc_call_id: call_id)
    params = construct_params(convert_call_params(call_id, 'no-answer')).merge!(ancestry: nil, callback: true)
    put :update, construct_params(params)
    result = parse_response(@response.body)
    call = ::Freshcaller::Call.last
    match_json(create_pattern(call))
    assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
  ensure
    Account.current.rollback(:freshcaller_ticket_revamp)
    set_auto_settings_to_default
  end
end
