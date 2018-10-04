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
      ticket_display_id: call.notable.notable.id,
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
    params.merge(ticket_display_id: ticket.id,
                 duration: Faker::Number.between(1, 3000),
                 note: Faker::Lorem.sentence(3))
    params
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
end
