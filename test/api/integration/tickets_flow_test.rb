require_relative '../test_helper'

class TicketsFlowTest < ActionDispatch::IntegrationTest
  include Helpers::TicketsTestHelper

  JSON_ROUTES = { '/api/tickets/1/restore' => 'put' }

  JSON_ROUTES.each do |path, verb|
    define_method("test_#{path}_#{verb}_with_multipart") do
      headers, params = encode_multipart(v2_ticket_params)
      skip_bullet do
        send(verb.to_sym, path, params, @write_headers.merge(headers))
      end
      assert_response 415
      response.body.must_match_json_expression(un_supported_media_type_error_pattern)
    end
  end

  def ticket
      ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
      ticket
  end

  def test_create_with_invalid_attachment_type
    skip_bullet do
      post '/api/tickets', { 'ticket' => { 'email' => 'test@abc.com', 'attachments' => 's', 'subject' => 'Test Subject', 'description' => 'Test', 'priority' => '1', 'status' => '2' } }, @headers.merge('CONTENT_TYPE' => 'multipart/form-data')
    end
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :data_type_mismatch, data_type: 'Array')])
  end

  def test_create_with_empty_attachment_array
    skip_bullet do
      post '/api/tickets', { 'ticket' => { 'email' => 'test@abc.com',  'subject' => 'Test Subject', 'description' => 'Test', 'priority' => '1', 'status' => '2', 'attachments' => [''] } }, @headers.merge('CONTENT_TYPE' => 'multipart/form-data')
    end
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :data_type_mismatch, data_type: 'valid format')])
  end

  def test_multipart_create_ticket_with_all_params
    cc_emails = [Faker::Internet.email, Faker::Internet.email]
    subject = Faker::Lorem.words(10).join(' ')
    description = Faker::Lorem.paragraph
    email = Faker::Internet.email
    tags = [Faker::Name.name, Faker::Name.name]
    @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
    params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                    priority: 2, status: 3, type: 'Problem', responder_id: @agent.id, source: 1, tags: tags,
                    due_by: 14.days.since.iso8601, fr_due_by: 1.days.since.iso8601, group_id: @create_group.id }
    tkt_field1 = create_custom_field('test_custom_decimal', 'decimal')
    tkt_field2 = create_custom_field('test_custom_checkbox', 'checkbox')
    field1 = tkt_field1.name
    field2 = tkt_field2.name
    headers, params = encode_multipart(params_hash.merge(custom_fields: { field1.to_sym => '2.34', field2.to_sym => 'false' }), 'attachments[]', File.join(Rails.root, 'test/api/fixtures/files/image33kb.jpg'), 'image/jpg', true)
    skip_bullet do
      post '/api/tickets', params, @headers.merge(headers)
    end
    [tkt_field1, tkt_field2].each(&:destroy)
    assert_response 201
    match_json(ticket_pattern(params_hash.merge(custom_fields: { field1.to_sym => '2.34', field2.to_sym => false }), Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    assert Helpdesk::Ticket.last.attachments.count == 1
  end

  def test_multipart_create_note_with_all_params
    body = Faker::Lorem.paragraph
    email = [Faker::Internet.email, Faker::Internet.email]
    params_hash = { body: body, notify_emails: email, private: true, user_id: @agent.id }
    parent_ticket = Helpdesk::Ticket.last
    headers, params = encode_multipart(params_hash, 'attachments[]', File.join(Rails.root, 'test/api/fixtures/files/image33kb.jpg'), 'image/jpg', true)
    skip_bullet do
      post "/api/tickets/#{parent_ticket.display_id}/notes", params, @headers.merge(headers)
    end
    assert_response 201
    assert_equal true, Helpdesk::Note.last.private
    assert_equal @agent.id, Helpdesk::Note.last.user_id
  end

  def test_multipart_create_reply_with_all_params
    body = Faker::Lorem.paragraph
    email = [Faker::Internet.email, Faker::Internet.email]
    bcc_emails = [Faker::Internet.email, Faker::Internet.email]
    params_hash = { body: body, cc_emails: email, bcc_emails: bcc_emails, user_id: @agent.id }
    parent_ticket = Helpdesk::Ticket.last
    headers, params = encode_multipart(params_hash, 'attachments[]', File.join(Rails.root, 'test/api/fixtures/files/image33kb.jpg'), 'image/jpg', true)
    skip_bullet do
      post "/api/tickets/#{parent_ticket.display_id}/reply", params, @headers.merge(headers)
    end
    assert_response 201
    assert_equal @agent.id, Helpdesk::Note.last.user_id
  end

  def test_empty_tags_and_cc_emails
    skip_bullet do
      params = v2_ticket_params.merge(tags: [Faker::Name.name], cc_emails: [Faker::Internet.email])
      post '/api/tickets', params.to_json, @write_headers
      ticket = Helpdesk::Ticket.find_by_subject(params[:subject])
      assert_response 201
      assert ticket.tags.count == 1
      assert ticket.cc_email[:cc_emails].count == 1

      put "/api/tickets/#{ticket.id}", { tags: nil }.to_json, @write_headers
      match_json([bad_request_error_pattern('tags', :data_type_mismatch, data_type: 'Array')])
      assert_response 400

      put "/api/tickets/#{ticket.id}", { tags: [] }.to_json, @write_headers
      assert_response 200
      assert ticket.reload.tags.count == 0
    end
  end

  def test_caching_when_updating_note_body
    skip_bullet do
      note = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
      ticket.update_column(:deleted, false)
      turn_on_caching
      get "/api/v2/tickets/#{ticket.display_id}", { include: 'notes' }, @write_headers
      note.note_body.body = 'Test update note body'
      note.save
      get "/api/v2/tickets/#{ticket.display_id}", { include: 'notes' }, @write_headers
      turn_off_caching
      parsed_response = JSON.parse(response.body)['notes']
      notes = parsed_response.select { |n| n['id'] = note.id } if parsed_response
      assert_response 200
      assert_equal 'Test update note body', notes[0]['body']
    end
  end

  def test_custom_date_utc_format
    t = ticket
    time = Time.now.in_time_zone("Chennai")
    Helpdesk::Ticket.any_instance.stubs(:custom_field).returns({:custom_date_1 => time})

    # without CustomFieldDecorator
    CustomFieldDecorator.stubs(:utc_format).returns({:custom_date_1 => time})
    get "/api/v2/tickets/#{t.display_id}", nil, @write_headers
    parsed_response = JSON.parse(response.body)['custom_fields']
    assert_equal time.iso8601, parsed_response['custom_date_1']
    assert_not_equal time.utc.iso8601, parsed_response['custom_date_1']

    # with CustomFieldDecorator
    CustomFieldDecorator.unstub(:utc_format)
    get "/api/v2/tickets/#{t.display_id}", nil, @write_headers
    parsed_response = JSON.parse(response.body)['custom_fields']
    assert_equal time.utc.iso8601, parsed_response['custom_date_1']
    Helpdesk::Ticket.any_instance.unstub(:custom_field)
  end
end
