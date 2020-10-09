module Freshcaller::CallsTestHelper
  def create_pattern(call)
    {
      id: call.id,
      fc_call_id: call.fc_call_id,
      recording_status: call.recording_status,
      ticket_display_id: nil,
      note_id: nil
    }
  end

  def ticket_with_note_pattern(call)
    {
      id: call.id,
      fc_call_id: call.fc_call_id,
      recording_status: call.recording_status,
      ticket_display_id: call.notable.notable.display_id,
      note_id: call.notable.id
    }
  end

  def ticket_only_pattern(call)
    {
      id: call.id,
      fc_call_id: call.fc_call_id,
      recording_status: call.recording_status,
      ticket_display_id: call.notable.display_id,
      note_id: nil
    }
  end

  def convert_call_params(call_id, status)
    {
      version: 'channel',
      id: call_id,
      call_type: 'incoming',
      call_status: status,
      customer_number: Faker::PhoneNumber.phone_number.to_s,
      customer_location: Faker::Address.country.to_s,
      call_created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}.to_s,
      agent_number: Faker::PhoneNumber.phone_number.to_s
    }
  end

  def convert_incoming_call_params(call_id, status)
    convert_call_params(call_id, status).update({ call_type: 'incoming' })
  end

  def convert_call_to_note_params(call_id, status)
    ticket = create_ticket
    params = convert_call_params(call_id, status)
    params = params.merge(ticket_display_id: ticket.display_id.to_s,
                 duration: Faker::Number.between(1, 3000),
                 note: Faker::Lorem.sentence(3))
    params
  end

  def call_note_params(call_id, status)
    params = convert_call_params(call_id, status)
    params.merge!(note: Faker::Lorem.sentence(3))
  end

  def update_invalid_params(call_id)
    {
      version: 'channel',
      id: call_id,
      call_status: 'cancelled',
      customer_number: 1_234_567,
      customer_location: 1,
      call_created_at: 1,
      agent_number: 1_234_567,
      ticket_display_id: 1,
      duration: '10',
      note: 1,
      agent_email: 'invalid_email',
      recording_status: 4
    }
  end

  def create_call(params)
    ::Freshcaller::Call.create(params)
  end

  def create_ticket
    ticket = Helpdesk::Ticket.new(requester_id: @agent.id, subject: Faker::Lorem.words(3))
    ticket.save
    ticket
  end

  def get_call_id
    Random.rand(2..100000)
  end

  def set_auto_settings_to_default
    fc_account = Account.current.freshcaller_account
    fc_account.settings = Freshcaller::Account::DEFAULT_SETTINGS
    fc_account.save
  end

  def set_auto_settings(call_type, condition)
    fc_account = Account.current.freshcaller_account
    settings_hash = fc_account.settings.presence || Freshcaller::Account::DEFAULT_SETTINGS
    settings_hash[:automatic_ticket_creation][call_type] = condition
    fc_account.settings = settings_hash
    fc_account.save
  end

  private

    def assert_create_unauthorized
      post :create, construct_params(version: 'channel', fc_call_id: get_call_id)
      assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:unauthorized]
    end

    def assert_create
      post :create, construct_params(version: 'channel', fc_call_id: get_call_id)
      result = parse_response(@response.body)
      match_json(create_pattern(::Freshcaller::Call.last))
      assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
    end

    def assert_update
      call_id = get_call_id
      create_call(fc_call_id: call_id)
      put :update, construct_params(version: 'channel', id: call_id, recording_status: 1)
      call = ::Freshcaller::Call.last
      match_json(create_pattern(call))
      assert_equal 1, call.recording_status
      assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
    end

    def assert_voice_mail_missed_call(status)
      call_id = get_call_id
      create_call(fc_call_id: call_id)
      put :update, construct_params(convert_incoming_call_params(call_id, status))
      result = parse_response(@response.body)
      call = ::Freshcaller::Call.last
      assert_missed_call(response, call) if status == 'no-answer'
      assert_voicemail(response, call) if status == 'voicemail'
      assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:created]
    end

    def assert_missed_call(_response, call)
      match_json(ticket_only_pattern(call))
      assert_equal call.notable.description.present?, true # for missed call, the call will be directly assocaited to ticket
      assert_equal call.notable.description_html.present?, true
    end

    def assert_voicemail(_response, call)
      match_json(ticket_with_note_pattern(call))
      assert_equal call.notable.notable.description.present?, true # for voicemail, the call will be associated to note of a ticket
      assert_equal call.notable.notable.description_html.present?, true
    end

    def assert_voicemail_missed_call_unauthorized(status)
      call_id = get_call_id
      create_call(fc_call_id: call_id)
      put :update, construct_params(convert_incoming_call_params(call_id, status))
      assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:unauthorized]
    end

    def set_auth_header
      request.env['HTTP_AUTHORIZATION'] = "token=#{sign_payload('account_id': '1', 'api_key': @agent.single_access_token)}"
    end

    def auth_header_with_agent_email
      request.env['HTTP_AUTHORIZATION'] = "token=#{sign_payload('account_id': '1', 'api_key': @agent.single_access_token, 'agent_email': @agent.email)}"
    end

    def auth_header_with_contact_key
      contact = @account.users.contacts.first
      request.env['HTTP_AUTHORIZATION'] = "token=#{sign_payload('account_id': '1', 'api_key': contact.single_access_token)}"
    end

    def invalid_auth_header
      request.env['HTTP_AUTHORIZATION'] = "token=#{sign_payload('account_id': '1', 'api_key': 'xxx')}"
    end

    def set_basic_auth_header
      request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(@agent.single_access_token, 'X')
    end
end
