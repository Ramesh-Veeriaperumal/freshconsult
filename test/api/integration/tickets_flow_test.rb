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
    match_json([bad_request_error_pattern('attachments', 'data_type_mismatch', data_type: 'Array')])
  end

  def test_create_with_empty_attachment_array
    skip_bullet do
      post '/api/tickets', { 'ticket' => { 'email' => 'test@abc.com',  'subject' => 'Test Subject', 'description' => 'Test', 'priority' => '1', 'status' => '2', 'attachments' => [''] } }, @headers.merge('CONTENT_TYPE' => 'multipart/form-data')
    end
    assert_response 400
    match_json([bad_request_error_pattern('attachments', 'data_type_mismatch', data_type: 'valid format')])
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

  def sample_product
    Product.all.detect { |p| p.primary_email_config.present? } || create_product
  end

  def other_product(product)
    Product.where('id != ?', product.id).first || create_product
  end

  def sample_group
    Group.first || create_group(@account)
  end

  def other_group(group)
    Group.where('id != ?', group.id).first || create_group(@account)
  end

  def agent(group)
    group.agents.first || add_agent(@account, group_id: group.id, name: Faker::Name.name, email: Faker::Internet.email, active: 1, role: 1,
                                              agent: 1, role_ids: [@account.roles.find_by_name('Agent').id.to_s], ticket_permission: 1)
  end

  def other_email_config(*email_configs)
    EmailConfig.where('id not in (?) and primary_role = false', email_configs.map(&:id)).first || create_email_config
  end

  def v2_ticket_params_sans_group_responder
    v2_ticket_params.except(:group_id, :responder_id)
  end

  def setup_for_email_config_product_test
    @product_1 ||= sample_product
    @primary_email_config_1 ||= @product_1.primary_email_config
    @group_1 ||= sample_group
    @group_2 ||= other_group(@group_1)
    @group_2.agent_groups = []
    @group_2.reload
    @primary_email_config_1.update_column(:group_id, @group_1.id)
    @primary_email_config_1.reload
    @responder ||= agent(@group_1)
    @product_2 ||= other_product(@product_1)
    @primary_email_config_2 ||= @product_2.primary_email_config
    @primary_email_config_2.update_column(:group_id, @group_2.id)
    @primary_email_config_2.reload
    @email_config_1 ||= other_email_config(@primary_email_config_1, @primary_email_config_2)
    @email_config_1.update_column(:product_id, @product_2.id)
    @email_config_1.update_column(:group_id, nil)
    @email_config_1.reload
  end

  def test_email_config_product_nil_values
    setup_for_email_config_product_test
    params = v2_ticket_params_sans_group_responder.merge(requester_id: @agent.id, email_config_id: nil, product_id: nil).to_json
    skip_bullet { post '/api/tickets', params, @write_headers }
    assert_response 201
    ticket = Helpdesk::Ticket.last
    assert_nil ticket.email_config
    assert_nil ticket.product
    assert_nil ticket.group
  end

  def test_responder_product_with_matching_email_config_and_group
    setup_for_email_config_product_test
    params = v2_ticket_params_sans_group_responder.merge(responder_id: @responder.id, product_id: @product_1.id).to_json
    skip_bullet { post '/api/tickets', params, @write_headers }
    assert_response 201
    assert_equal @group_1, Helpdesk::Ticket.last.group
  end

  def test_email_config_responder_with_matching_group
    setup_for_email_config_product_test
    params = v2_ticket_params_sans_group_responder.merge(responder_id: @responder.id, email_config_id: @primary_email_config_1.id).to_json
    skip_bullet { post '/api/tickets', params, @write_headers }
    assert_response 201
    assert_equal @group_1, Helpdesk::Ticket.last.group
  end

  def test_responder_group_mismatch
    setup_for_email_config_product_test
    params = v2_ticket_params_sans_group_responder.merge(responder_id: @responder.id, group_id: @group_2.id).to_json
    skip_bullet { post '/api/tickets', params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('responder_id', 'not_part_of_group')])

    # mismatched group will get assigned in callbacks from ec
    params = v2_ticket_params_sans_group_responder.merge(responder_id: @responder.id, email_config_id: @primary_email_config_2.id).to_json
    skip_bullet { post '/api/tickets', params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('responder_id', 'not_part_of_email_config_group')])

    # mismatched group will get assigned in callbacks, ec from product and group from ec in next save.
    params = v2_ticket_params_sans_group_responder.merge(responder_id: @responder.id, product_id: @product_2.id).to_json
    skip_bullet { post '/api/tickets', params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('responder_id', 'not_part_of_email_config_group')])

    last_ticket = Helpdesk::Ticket.last
    last_ticket.update_column(:responder_id, @responder.id)
    last_ticket.update_column(:group_id, nil)
    last_ticket.schema_less_ticket.update_column(:product_id, @product_1.id)

    # mismatched group will get assigned in callbacks, ec from product and group from ec in next save.
    params = v2_ticket_params_sans_group_responder.merge(product_id: @product_2.id).to_json
    skip_bullet { put "/api/tickets/#{last_ticket.display_id}", params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('responder_id', 'not_part_of_email_config_group')])

    # mismatched group will get assigned in callbacks from ec
    params = v2_ticket_params_sans_group_responder.merge(email_config_id: @primary_email_config_2.id).to_json
    skip_bullet { put "/api/tickets/#{last_ticket.display_id}", params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('responder_id', 'not_part_of_email_config_group')])
  end

  def test_email_config_product_present_mismatch
    setup_for_email_config_product_test
    # create mismatch
    params = v2_ticket_params_sans_group_responder.merge(requester_id: @agent.id, email_config_id: @email_config_1.id,
                                                         product_id: @product_1.id).to_json
    skip_bullet { post '/api/tickets', params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('product_id', 'product_mismatch')])

    params = v2_ticket_params_sans_group_responder.merge(requester_id: @agent.id, email_config_id: @email_config_1.id,
                                                         product_id: nil).to_json
    skip_bullet { post '/api/tickets', params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('product_id', 'product_mismatch')])

    last_ticket = Helpdesk::Ticket.last
    last_ticket.update_column(:group_id, nil)
    last_ticket.schema_less_ticket.update_column(:product_id, @product_2.id)
    last_ticket.reload

    # nil will get assigned to ec in callbacks
    params = v2_ticket_params_sans_group_responder.merge(email_config_id: @email_config_1.id, product_id: nil).to_json
    skip_bullet { put "/api/tickets/#{last_ticket.display_id}", params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('email_config_id', 'email_config_mismatch')])

    # update mismatch
    params = { email_config_id: @email_config_1.id, product_id: @product_1.id }.to_json
    skip_bullet { put "/api/tickets/#{last_ticket.display_id}", params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('email_config_id', 'email_config_mismatch')])

    params = v2_ticket_params_sans_group_responder.merge(requester_id: @agent.id, email_config_id: nil,
                                                         product_id: @product_1.id).to_json
    skip_bullet { post '/api/tickets', params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('email_config_id', 'email_config_mismatch')])

    last_ticket.schema_less_ticket.update_column(:product_id, nil)
    last_ticket.update_column(:email_config_id, nil)
    last_ticket.reload

    # ec will not be nil after callbacks when both are nil
    params = v2_ticket_params_sans_group_responder.merge(email_config_id: nil, product_id: @product_1.id).to_json
    skip_bullet { put "/api/tickets/#{last_ticket.display_id}", params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('email_config_id', 'email_config_mismatch')])

    # update mismatch when both are nil
    params = v2_ticket_params_sans_group_responder.merge(email_config_id: @primary_email_config_2.id, product_id: @product_1.id).to_json
    skip_bullet { put "/api/tickets/#{last_ticket.display_id}", params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('email_config_id', 'email_config_mismatch')])

    last_ticket.schema_less_ticket.update_column(:product_id, @product_2.id)
    last_ticket.reload

    # ec will not be nil after callbacks when email_config_id is nil
    params = v2_ticket_params_sans_group_responder.merge(email_config_id: nil, product_id: @product_1.id).to_json
    skip_bullet { put "/api/tickets/#{last_ticket.display_id}", params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('email_config_id', 'email_config_mismatch')])

    last_ticket.update_column(:email_config_id, @primary_email_config_1.id)
    last_ticket.reload

    # ec will be nil after callbacks
    params = v2_ticket_params_sans_group_responder.merge(email_config_id: @primary_email_config_1.id, product_id: nil).to_json
    skip_bullet { put "/api/tickets/#{last_ticket.display_id}", params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('email_config_id', 'email_config_mismatch')])

    # ec will not be nil after callbacks when both are present
    params = v2_ticket_params_sans_group_responder.merge(email_config_id: nil, product_id: @product_1.id).to_json
    skip_bullet { put "/api/tickets/#{last_ticket.display_id}", params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('email_config_id', 'email_config_mismatch')])

    # update_mismatch when both are present
    params = v2_ticket_params_sans_group_responder.merge(email_config_id: @primary_email_config_2.id, product_id: @product_1.id).to_json
    skip_bullet { put "/api/tickets/#{last_ticket.display_id}", params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('email_config_id', 'email_config_mismatch')])

    last_ticket.schema_less_ticket.update_column(:product_id, nil)
    last_ticket.reload

    # ec will not be nil after callbacks when product is nil
    params = v2_ticket_params_sans_group_responder.merge(email_config_id: nil, product_id: @product_1.id).to_json
    skip_bullet { put "/api/tickets/#{last_ticket.display_id}", params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('email_config_id', 'email_config_mismatch')])

    # update mismatch when product is nil
    params = v2_ticket_params_sans_group_responder.merge(email_config_id: @primary_email_config_2.id, product_id: @product_1.id).to_json
    skip_bullet { put "/api/tickets/#{last_ticket.display_id}", params, @write_headers }
    assert_response 400
    match_json([bad_request_error_pattern('email_config_id', 'email_config_mismatch')])
  end

  def test_email_config_product_present_valid
    setup_for_email_config_product_test
    params = v2_ticket_params_sans_group_responder.merge(requester_id: @agent.id, email_config_id: @email_config_1.id,
                                                         product_id: @product_2.id).to_json
    skip_bullet { post '/api/tickets', params, @write_headers }
    assert_response 201
    ticket = Helpdesk::Ticket.last
    assert_equal @email_config_1, ticket.email_config
    assert_equal @product_2, ticket.product
    assert_nil ticket.group
  end

  def test_default_product_assignment_from_email_config
    setup_for_email_config_product_test

    params = v2_ticket_params_sans_group_responder.merge(requester_id: @agent.id, email_config_id: @email_config_1.id).to_json
    skip_bullet { post '/api/tickets', params, @write_headers }
    assert_response 201
    ticket = Helpdesk::Ticket.last
    assert_equal @email_config_1, ticket.email_config
    assert_equal @product_2, ticket.product
    assert_nil ticket.group
  end

  def test_default_email_config_assignment_from_product
    setup_for_email_config_product_test

    params = v2_ticket_params_sans_group_responder.merge(requester_id: @agent.id,
                                                         product_id: @product_1.id).to_json
    skip_bullet { post '/api/tickets', params, @write_headers }
    p response.body
    assert_response 201
    ticket = Helpdesk::Ticket.last
    assert_equal @product_1, ticket.product
    assert_equal @primary_email_config_1, ticket.email_config
    assert_equal @group_1, ticket.reload.group

    # default email_config gets assigned on update as it is nil.
    skip_bullet { put "/api/tickets/#{ticket.display_id}", { email_config_id: nil }.to_json, @write_headers }

    params = v2_ticket_params_sans_group_responder.merge(product_id: @product_2.id).to_json
    skip_bullet { put "/api/tickets/#{ticket.display_id}", params, @write_headers }
    assert_response 200
    assert_equal @primary_email_config_2, ticket.reload.email_config
    assert_equal @product_2, ticket.product
    assert_equal @group_1, ticket.reload.group

    # passed email_config gets assigned as it matches with the product
    params = v2_ticket_params_sans_group_responder.merge(email_config_id: @email_config_1.id, product_id: @product_2.id).to_json
    skip_bullet { put "/api/tickets/#{ticket.display_id}", params, @write_headers }
    assert_response 200
    assert_equal @email_config_1, ticket.reload.email_config
    assert_equal @product_2, ticket.product
    assert_equal @group_1, ticket.reload.group
  end

  def test_email_config_with_matching_group
    setup_for_email_config_product_test
    last_ticket = Helpdesk::Ticket.last
    params = v2_ticket_params_sans_group_responder.merge(email_config_id: @primary_email_config_2.id, group_id: @group_1.id).to_json
    skip_bullet { put "/api/tickets/#{last_ticket.display_id}", params, @write_headers }
    assert_response 200
    assert_equal @group_1, last_ticket.reload.group
    assert_equal @primary_email_config_2, last_ticket.email_config
  end

  def test_empty_tags_and_cc_emails
    skip_bullet do
      params = v2_ticket_params.merge(tags: [Faker::Name.name], cc_emails: [Faker::Internet.email])
      post '/api/tickets', params.to_json, @write_headers
      ticket = Helpdesk::Ticket.find_by_subject(params[:subject])
      assert_response 201
      assert ticket.tags.count == 1
      assert ticket.cc_email[:cc_emails].count == 1

      put "/api/tickets/#{ticket.id}", { tags: nil, cc_emails: nil }.to_json, @write_headers
      match_json([bad_request_error_pattern('tags', 'data_type_mismatch', data_type: 'Array'),
                  bad_request_error_pattern('cc_emails', 'data_type_mismatch', data_type: 'Array')])
      assert_response 400

      put "/api/tickets/#{ticket.id}", { tags: [], cc_emails: [] }.to_json, @write_headers
      assert_response 200
      assert ticket.reload.tags.count == 0
      assert ticket.reload.cc_email.count == 0
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
