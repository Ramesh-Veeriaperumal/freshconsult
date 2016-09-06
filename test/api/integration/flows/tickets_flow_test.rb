require_relative '../../test_helper'

class TicketsFlowTest < ActionDispatch::IntegrationTest
  include TicketsTestHelper
  include ScenarioAutomationsTestHelper

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

  def ticket_params_hash
    cc_emails = [Faker::Internet.email, Faker::Internet.email]
    subject = Faker::Lorem.words(10).join(' ')
    description = Faker::Lorem.paragraph
    email = Faker::Internet.email
    tags = [Faker::Name.name, Faker::Name.name]
    @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
    params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                    priority: 2, status: 3, type: 'Problem', responder_id: @agent.id, source: 1, tags: tags,
                    due_by: 14.days.since.iso8601, fr_due_by: 1.days.since.iso8601, group_id: @create_group.id }
    params_hash
  end

  def ticket
    ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
    ticket
  end

  def fetch_email_config
    EmailConfig.first || create_email_config
  end

  def test_create_with_invalid_attachment_type
    skip_bullet do
      post '/api/tickets', { 'ticket' => { 'email' => 'test@abc.com', 'attachments' => 's', 'subject' => 'Test Subject', 'description' => 'Test', 'priority' => '1', 'status' => '2' } }, @headers.merge('CONTENT_TYPE' => 'multipart/form-data')
    end
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :datatype_mismatch, prepend_msg: :input_received, given_data_type: String, expected_data_type: Array)])
  end

  def test_create_with_empty_attachment_array
    skip_bullet do
      post '/api/tickets', { 'ticket' => { 'email' => 'test@abc.com',  'subject' => 'Test Subject', 'description' => 'Test', 'priority' => '1', 'status' => '2', 'attachments' => [''] } }, @headers.merge('CONTENT_TYPE' => 'multipart/form-data')
    end
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_datatype_mismatch, expected_data_type: 'valid file format')])
  end

  def test_multipart_create_ticket_with_all_params
    cc_emails = [Faker::Internet.email, Faker::Internet.email]
    subject = Faker::Lorem.words(10).join(' ')
    description = Faker::Lorem.paragraph
    email = Faker::Internet.email
    tags = [Faker::Name.name, Faker::Name.name]
    @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
    params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                    priority: 2, status: 7, type: 'Problem', responder_id: @agent.id, source: 1, tags: tags,
                    due_by: 14.days.since.iso8601, fr_due_by: 1.days.since.iso8601, group_id: @create_group.id }
    tkt_field1 = create_custom_field('test_custom_decimal', 'decimal')
    tkt_field2 = create_custom_field('test_custom_checkbox', 'checkbox')
    field1 = tkt_field1.name[0..-3]
    field2 = tkt_field2.name[0..-3]
    headers, params = encode_multipart(params_hash.merge(custom_fields: { field1.to_sym => '2.34', field2.to_sym => 'false' }), 'attachments[]', File.join(Rails.root, 'test/api/fixtures/files/image33kb.jpg'), 'image/jpg', true)
    skip_bullet do
      post '/api/tickets', params, @headers.merge(headers)
    end
    [tkt_field1, tkt_field2].each(&:destroy)
    assert_response 201
    @account.make_current
    match_json(ticket_pattern(params_hash.merge(custom_fields: { field1.to_sym => '2.34', field2.to_sym => false }), Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    assert Helpdesk::Ticket.last.attachments.count == 1
  end

  def test_multipart_create_outbound_ticket_with_all_params
    cc_emails = [Faker::Internet.email, Faker::Internet.email]
    subject = Faker::Lorem.words(10).join(' ')
    description = Faker::Lorem.paragraph
    email = Faker::Internet.email
    tags = [Faker::Name.name, Faker::Name.name]
    @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
    params_hash = { email: email, email_config_id: fetch_email_config.id, cc_emails: cc_emails, description: description, subject: subject,
                    priority: 2, type: 'Problem', tags: tags, group_id: @create_group.id }
    tkt_field1 = create_custom_field('test_custom_decimal', 'decimal')
    tkt_field2 = create_custom_field('test_custom_checkbox', 'checkbox')
    field1 = tkt_field1.name[0..-3]
    field2 = tkt_field2.name[0..-3]
    headers, params = encode_multipart(params_hash.merge(custom_fields: { field1.to_sym => '2.34', field2.to_sym => 'false' }), 'attachments[]', File.join(Rails.root, 'test/api/fixtures/files/image33kb.jpg'), 'image/jpg', true)
    skip_bullet do
      post '/api/tickets/outbound_email', params, @headers.merge(headers)
    end
    [tkt_field1, tkt_field2].each(&:destroy)
    @account.make_current
    match_json(ticket_pattern(params_hash.merge(source: 10, responder_id: @agent.id, status: 5, custom_fields: { field1.to_sym => '2.34', field2.to_sym => false }), Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    assert Helpdesk::Ticket.last.attachments.count == 1
    assert_response 201
  end

  def test_multipart_create_note_with_all_params
    body = Faker::Lorem.paragraph
    agent_email1 = @agent.email
    agent_email2 = User.find { |x| x.email != agent_email1 && x.helpdesk_agent == true }.try(:email) || add_test_agent(@account, role: Role.find_by_name('Agent').id).email
    email = [agent_email2, agent_email1]
    params_hash = { body: body, notify_emails: email, private: true, user_id: @agent.id }
    parent_ticket = Helpdesk::Ticket.last
    previous_updated_at = parent_ticket.updated_at
    headers, params = encode_multipart(params_hash, 'attachments[]', File.join(Rails.root, 'test/api/fixtures/files/image33kb.jpg'), 'image/jpg', true)
    skip_bullet do
      post "/api/tickets/#{parent_ticket.display_id}/notes", params, @headers.merge(headers)
    end
    assert_response 201
    assert_equal true, Helpdesk::Note.last.private
    assert_equal @agent.id, Helpdesk::Note.last.user_id
    assert Helpdesk::Ticket.find(parent_ticket.id).updated_at > previous_updated_at
  end

  def test_multipart_create_reply_with_all_params
    body = Faker::Lorem.paragraph
    email = [Faker::Internet.email, Faker::Internet.email]
    bcc_emails = [Faker::Internet.email, Faker::Internet.email]
    params_hash = { body: body, cc_emails: email, bcc_emails: bcc_emails, user_id: @agent.id }
    parent_ticket = Helpdesk::Ticket.last
    previous_updated_at = parent_ticket.updated_at
    headers, params = encode_multipart(params_hash, 'attachments[]', File.join(Rails.root, 'test/api/fixtures/files/image33kb.jpg'), 'image/jpg', true)
    skip_bullet do
      post "/api/tickets/#{parent_ticket.display_id}/reply", params, @headers.merge(headers)
    end
    assert_response 201
    assert_equal @agent.id, Helpdesk::Note.last.user_id
    assert Helpdesk::Ticket.find(parent_ticket.id).updated_at > previous_updated_at
  end

  def test_empty_tags_and_cc_emails
    skip_bullet do
      params = v2_ticket_params.merge(tags: [Faker::Name.name], cc_emails: [Faker::Internet.email])
      post '/api/tickets', params.to_json, @write_headers
      ticket = Helpdesk::Ticket.find_by_subject(params[:subject])
      assert_response 201
      assert ticket.tags.count == 1
      assert ticket.cc_email[:cc_emails].count == 1
      assert ticket.cc_email[:tkt_cc].count == 1

      put "/api/tickets/#{ticket.id}", { tags: nil }.to_json, @write_headers
      match_json([bad_request_error_pattern('tags', :datatype_mismatch, prepend_msg: :input_received, given_data_type: 'Null', expected_data_type: Array)])
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
      enable_cache do
        get "/api/v2/tickets/#{ticket.display_id}", { include: 'conversations' }, @write_headers
        note.note_body.body = 'Test update note body'
        note.save
        get "/api/v2/tickets/#{ticket.display_id}", { include: 'conversations' }, @write_headers
        parsed_response = JSON.parse(response.body)['conversations']
        conversations = parsed_response.select { |n| n['id'] = note.id } if parsed_response
        assert_response 200
        assert_equal 'Test update note body', conversations[0]['body_text']
      end
    end
  end

  def test_custom_date_utc_format
    t = ticket
    time = Time.zone.now.in_time_zone('Chennai')
    Helpdesk::Ticket.any_instance.stubs(:custom_field_via_mapping).returns('custom_date_1' => time)

    # without CustomFieldDecorator
    TicketDecorator.any_instance.stubs(:utc_format).returns(time)
    FlexifieldDef.any_instance.stubs(:ff_alias_column_mapping).returns('custom_date_1' => 'custom_date')
    get "/api/v2/tickets/#{t.display_id}", nil, @write_headers
    parsed_response = JSON.parse(response.body)['custom_fields']
    assert_equal time.iso8601, parsed_response['custom_date']
    assert_not_equal time.utc.iso8601, parsed_response['custom_date']

    # with CustomFieldDecorator
    TicketDecorator.any_instance.unstub(:utc_format)
    get "/api/v2/tickets/#{t.display_id}", nil, @write_headers
    parsed_response = JSON.parse(response.body)['custom_fields']
    assert_equal time.utc.iso8601, parsed_response['custom_date']
    Helpdesk::Ticket.any_instance.unstub(:custom_field_via_mapping)
  end

  def test_updated_at_of_ticket_with_description_update
    # IN API
    ticket = Helpdesk::Ticket.where(spam: false, deleted: false, source: 1).first
    previous_updated_at = ticket.updated_at
    skip_bullet do
      put "/api/tickets/#{ticket.id}", { description: Faker::Lorem.paragraph }.to_json, @write_headers
    end
    assert_response 200
    assert Helpdesk::Ticket.find(ticket.id).updated_at > previous_updated_at

    # IN WEB
    # previous_updated_at_for_web = ticket.updated_at
    # skip_bullet do
    #   put "helpdesk/tickets/#{ticket.id}", { helpdesk_ticket: { ticket_body_attributes: { description: Faker::Lorem.paragraph } } }.to_json, @write_headers
    # end
    # assert_response 302
    # assert Helpdesk::Ticket.find(ticket.id).updated_at > previous_updated_at_for_web

    # IN API V1
    previous_updated_at_for_api_v1 = ticket.updated_at
    skip_bullet do
      put "helpdesk/tickets/#{ticket.id}.json", { helpdesk_ticket: { ticket_body_attributes: { description_html: Faker::Lorem.paragraph } } }.to_json, @write_headers
    end
    assert_response 200
    assert Helpdesk::Ticket.find(ticket.id).updated_at > previous_updated_at_for_api_v1
  end

  def test_updated_at_of_ticket_with_no_description_update
    # IN API
    ticket = create_ticket(requested_id: @agent.id)
    previous_updated_at = ticket.updated_at
    skip_bullet do
      put "/api/tickets/#{ticket.id}", { description: ticket.description_html }.to_json, @write_headers
    end
    assert_response 200
    assert Helpdesk::Ticket.find(ticket.id).updated_at.to_i == previous_updated_at.to_i

    # IN WEB
    # skip_bullet do
    #   put "helpdesk/tickets/#{ticket.id}", { helpdesk_ticket: { ticket_body_attributes: { description: ticket.description } } }.to_json, @write_headers
    # end
    # assert_response 302
    # assert Helpdesk::Ticket.find(ticket.id).updated_at.to_i == previous_updated_at.to_i

    # IN API V1
    skip_bullet do
      put "helpdesk/tickets/#{ticket.id}.json", { helpdesk_ticket: { ticket_body_attributes: { description_html: ticket.description_html } } }.to_json, @write_headers
    end
    assert_response 200
    assert Helpdesk::Ticket.find(ticket.id).updated_at.to_i == previous_updated_at.to_i
  end

  def test_updated_at_of_ticket_with_note_update
    # In API
    note = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
    ticket = note.notable
    sleep 1
    previous_updated_at = ticket.updated_at
    put("/api/conversations/#{note.id}", v2_note_update_payload, @write_headers)
    assert_response 200
    assert Helpdesk::Ticket.find(ticket.id).updated_at.to_i > previous_updated_at.to_i

    # IN Web
    # previous_updated_at_for_web = ticket.updated_at
    # put("/helpdesk/tickets/#{ticket.id}/notes/#{note.id}", { helpdesk_note: { body: Faker::Lorem.paragraph }}.to_json, @write_headers)
    # assert_response 302
    # assert Helpdesk::Ticket.find(ticket.id).updated_at > previous_updated_at_for_web

    # In API V1
    previous_updated_at_for_api_v1 = ticket.updated_at
    sleep 1

    put("/helpdesk/tickets/#{ticket.id}/conversations/#{note.id}.json", { helpdesk_note: { body_html: Faker::Lorem.paragraph } }.to_json, @write_headers)
    assert_response 200
    assert Helpdesk::Ticket.find(ticket.id).updated_at.to_i > previous_updated_at_for_api_v1.to_i
  end

  def test_updated_at_of_ticket_with_note_destroy
    # In API
    note = Helpdesk::Note.exclude_source('meta').visible.first
    ticket = note.notable
    previous_updated_at = ticket.updated_at
    sleep 1
    delete("/api/conversations/#{note.id}", nil, @headers)
    assert_response 204
    assert Helpdesk::Ticket.find(ticket.id).updated_at.to_i > previous_updated_at.to_i

    # In Web
    # note = Helpdesk::Note.exclude_source('meta').visible.first
    # ticket = note.notable
    # previous_updated_at_for_web = ticket.updated_at
    # delete("/helpdesk/tickets/#{ticket.id}/notes/#{note.id}", nil, @headers)
    # assert_response 302
    # assert Helpdesk::Ticket.find(ticket.id).updated_at > previous_updated_at_for_web

    # In API V1
    note = Helpdesk::Note.exclude_source('meta').visible.first
    ticket = note.notable
    previous_updated_at_for_api_v1 = ticket.updated_at
    sleep 1
    delete("/helpdesk/tickets/#{ticket.display_id}/notes/#{note.id}.json", nil, @headers)
    assert_response 200
    assert Helpdesk::Ticket.find(ticket.id).updated_at.to_i > previous_updated_at_for_api_v1.to_i
  end

  def test_updated_at_of_ticket_with_tags_add
    # IN API
    ticket = Helpdesk::Ticket.where('source != ? and deleted = ?', 10, false).last
    existing_tags = ticket.tag_names
    previous_updated_at = ticket.updated_at
    tags = existing_tags | [Faker::Name.name]
    skip_bullet do
      put "/api/tickets/#{ticket.id}", { tags: tags }.to_json, @write_headers
    end
    assert_response 200
    assert Helpdesk::Ticket.find(ticket.id).updated_at > previous_updated_at

    # #IN WEB
    # previous_updated_at_for_web = ticket.updated_at
    # skip_bullet do
    #   put "helpdesk/tickets/#{ticket.id}", { helpdesk: {  tags: "#{Faker::Name.name}" } }.to_json, @write_headers
    # end
    # assert_response 302
    # assert Helpdesk::Ticket.find(ticket.id).updated_at > previous_updated_at_for_web

    # IN API V1
    ticket = Helpdesk::Ticket.find(ticket.id)
    previous_updated_at_for_api_v1 = ticket.updated_at
    existing_tags = ticket.tag_names.join(',')
    tags = existing_tags.present? ? "#{existing_tags},#{Faker::Name.name}" : "#{Faker::Name.name}"
    sleep 1
    skip_bullet do
      put "helpdesk/tickets/#{ticket.id}.json", { helpdesk_ticket: {}, helpdesk: { tags: tags  } }.to_json, @write_headers
    end
    assert_response 200
    assert Helpdesk::Ticket.find(ticket.id).updated_at > previous_updated_at_for_api_v1
  end

  def test_updated_at_of_ticket_with_tags_remove
    # IN API
    ticket = Helpdesk::Ticket.where('source != ? and deleted = ?', 10, false).last
    ticket.tags = [Helpdesk::Tag.first]
    previous_updated_at = ticket.updated_at
    sleep 1
    skip_bullet do
      put "/api/tickets/#{ticket.id}", { tags: [] }.to_json, @write_headers
    end
    assert_response 200
    assert Helpdesk::Ticket.find(ticket.id).updated_at > previous_updated_at

    # IN WEB
    # ticket.tags = [Helpdesk::Tag.first]
    # previous_updated_at_for_web = ticket.updated_at
    # sleep 1
    # skip_bullet do
    #   put "helpdesk/tickets/#{ticket.id}", { helpdesk: {  tags: "" } }.to_json, @write_headers
    # end
    # assert_response 302
    # assert Helpdesk::Ticket.find(ticket.id).updated_at > previous_updated_at_for_web

    # IN API V1
    ticket = Helpdesk::Ticket.find(ticket.id)
    ticket.tags = [Helpdesk::Tag.first]
    previous_updated_at_for_api_v1 = ticket.updated_at
    sleep 1
    skip_bullet do
      put "helpdesk/tickets/#{ticket.id}.json", { helpdesk_ticket: {}, helpdesk: { tags: '' }  }.to_json, @write_headers
    end
    assert_response 200
    assert Helpdesk::Ticket.find(ticket.id).updated_at > previous_updated_at_for_api_v1
  end

  def test_updated_at_of_ticket_with_no_changes_to_tags
    # IN API
    ticket = Helpdesk::Ticket.where('source != ? and deleted = ?', 10, false).last
    tag = Helpdesk::Tag.first
    ticket.tags = [tag]
    previous_updated_at = ticket.updated_at
    skip_bullet do
      put "/api/tickets/#{ticket.id}", { tags: [tag.name] }.to_json, @write_headers
    end
    assert_response 200
    assert Helpdesk::Ticket.find(ticket.id).updated_at.to_i == previous_updated_at.to_i

    # IN WEB
    # skip_bullet do
    #   put "helpdesk/tickets/#{ticket.id}", { helpdesk: { tags: "#{tag.name}" } }.to_json, @write_headers
    # end
    # assert_response 302
    # assert Helpdesk::Ticket.find(ticket.id).updated_at.to_i == previous_updated_at.to_i

    # IN API V1
    skip_bullet do
      put "helpdesk/tickets/#{ticket.id}.json", { helpdesk_ticket: {}, helpdesk: { tags: "#{tag.name}" } }.to_json, @write_headers
    end
    assert_response 200
    assert Helpdesk::Ticket.find(ticket.id).updated_at.to_i == previous_updated_at.to_i
  end

  def test_cc_emails_notified
    Delayed::Job.delete_all
    cc_emails = [Faker::Internet.email, Faker::Internet.email]
    subject = Faker::Lorem.words(10).join(' ')
    description = Faker::Lorem.paragraph
    email = Faker::Internet.email
    tags = [Faker::Name.name, Faker::Name.name]
    @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
    params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                    priority: 2, status: 7, type: 'Problem', responder_id: @agent.id, source: 1, tags: tags,
                    due_by: 14.days.since.iso8601, fr_due_by: 1.days.since.iso8601, group_id: @create_group.id }
    headers, params = encode_multipart(params_hash, 'attachments[]', File.join(Rails.root, 'test/api/fixtures/files/image33kb.jpg'), 'image/jpg', true)
    skip_bullet do
      post '/api/tickets', params, @headers.merge(headers)
    end
    assert Delayed::Job.last.handler.include?('send_cc_email')
    10.times { Delayed::Job.reserve_and_run_one_job }
    assert_equal 0, Delayed::Job.count
  end

  def test_bulk_deletion
    skip_bullet do
      ticket_id = create_ticket(ticket_params_hash).display_id
      put "api/_/tickets/bulk_delete", {ids: [ticket_id]}.to_json, @write_headers
      assert_response 204

      put "api/_/tickets/bulk_delete", {ids: [ticket_id, ticket_id + 20]}.to_json, @write_headers
      assert_response 202

      put "api/_/tickets/bulk_delete", nil, @write_headers
      assert_response 400
    end
  end

   def test_bulk_spam
    skip_bullet do
      ticket_id = create_ticket(ticket_params_hash).display_id
      put "api/_/tickets/bulk_spam", {ids: [ticket_id]}.to_json, @write_headers
      assert_response 204

      put "api/_/tickets/bulk_spam", {ids: [ticket_id, ticket_id + 20]}.to_json, @write_headers
      assert_response 202

      put "api/_/tickets/bulk_spam", nil, @write_headers
      assert_response 400
    end
  end

  def test_execute_scenario
    skip_bullet do
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      put "api/_/tickets/#{ticket_id}/execute_scenario/#{scenario_id}", nil, @write_headers
      assert_response 204

      put "api/_/tickets/#{ticket_id + 20}/execute_scenario/#{scenario_id}", nil, @write_headers
      assert_response 404
    end
  end

  def test_bulk_execute_scenario
    skip_bullet do
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      put "api/_/tickets/bulk_execute_scenario/#{scenario_id}", {ids: [ticket_id]}.to_json, @write_headers
      assert_response 202
    end
  end
end
