require_relative '../test_helper'

class TicketsControllerTest < ActionController::TestCase
  def wrap_cname(params)
    { ticket: params }
  end

  def requester
    user = User.find { |x| x.id != @agent.id && x.helpdesk_agent == false } || add_new_user(@account)
    user
  end

  def ticket_params_hash
    cc_emails = [Faker::Internet.email, Faker::Internet.email]
    subject = Faker::Lorem.words(10).join(' ')
    description = Faker::Lorem.paragraph
    email = Faker::Internet.email
    params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                    priority: 2, status: 3, ticket_type: 'Problem', responder_id: @agent.id, source: 2, tags: ['tag1', 'tag2'],
                    due_by: 14.days.since.to_s, fr_due_by: 1.days.since.to_s, group_id: Group.first.id }
    params_hash
  end

  def test_create
    params = ticket_params_hash
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
  end

  def test_create_numericality_invalid
    params = ticket_params_hash.merge(requester_id: 'yu', responder_id: 'io', product_id: 'x', email_config_id: 'x',
                                      display_id: 'y', group_id: 'g')
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('requester_id', 'is not a number'),
                bad_request_error_pattern('responder_id', 'is not a number'),
                bad_request_error_pattern('product_id', 'is not a number'),
                bad_request_error_pattern('email_config_id', 'is not a number'),
                bad_request_error_pattern('display_id', 'is not a number'),
                bad_request_error_pattern('group_id', 'is not a number')])
  end

  def test_create_inclusion_invalid
    params = ticket_params_hash.merge(requester_id: requester.id, priority: 90, status: 56, ticket_type: 'jk', source: '89')
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('priority', 'is not included in the list', list: '1,2,3,4'),
                bad_request_error_pattern('status', 'is not included in the list', list: '2,3,4,5,6,7'),
                bad_request_error_pattern('ticket_type', 'is not included in the list', list: 'Question,Incident,Problem,Feature Request,Lead'),
                bad_request_error_pattern('source', 'is not included in the list', list: '1,2,3,4,5,6,7,8,9')])
  end

  def test_create_presence_requester_id_invalid
    params = ticket_params_hash.except(:email)
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('requester_id', "can't be blank")])
  end

  def test_create_presence_name_invalid
    params = ticket_params_hash.except(:email).merge(phone: Faker::PhoneNumber.phone_number)
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('name', "can't be blank")])
  end

  def test_create_email_format_invalid
    params = ticket_params_hash.merge(email: 'test@', cc_emails: ['the@'])
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('email', 'is not a valid email'),
                bad_request_error_pattern('cc_emails', 'is not a valid email')])
  end

  def test_create_data_type_invalid
    cc_emails = "#{Faker::Internet.email},#{Faker::Internet.email}"
    params = ticket_params_hash.merge(cc_emails: cc_emails, tags: 'tag1,tag2', custom_fields: [])
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('cc_emails', 'is not a/an Array'),
                bad_request_error_pattern('tags', 'is not a/an Array'),
                bad_request_error_pattern('custom_fields', 'is not a/an Hash')])
  end

  def test_create_date_time_invalid
    params = ticket_params_hash.merge(due_by: '7/7669/0', fr_due_by: '7/9889/0')
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('due_by', 'is not a date'),
                bad_request_error_pattern('fr_due_by', 'is not a date')])
  end

  def test_create_invalid_model
    params = ticket_params_hash.except(:email).merge(group_id: 89_089, product_id: 9090, email_config_id: 89_789, requester_id: 8989, responder_id: 8987)
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('requester_id', 'should be a valid email address'),
                bad_request_error_pattern('group', "can't be blank"),
                bad_request_error_pattern('responder', "can't be blank"),
                bad_request_error_pattern('email_config', "can't be blank")])
  end

  def test_create_extra_params_invalid
    params = ticket_params_hash.merge(junk: 'test')
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('junk', 'invalid_field')])
  end

  def test_create_empty_params
    params = {}
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('requester_id', "can't be blank")])
  end

  def test_create_returns_location_header
    params = ticket_params_hash
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    result = parse_response(@response.body)
    assert_equal true, response.headers.include?('Location')
    assert_equal "http://#{@request.host}/api/v2/tickets/#{result['display_id']}", response.headers['Location']
  end

  def test_create_with_existing_user
    params = ticket_params_hash.except(:email).merge(requester_id: requester.id)
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
  end

  def test_create_with_new_twitter_user
    params = ticket_params_hash.except(:email).merge(twitter_id: '@test')
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    assert User.last.twitter_id == '@test'
  end

  def test_create_with_new_phone_user
    phone = Faker::PhoneNumber.phone_number
    params = ticket_params_hash.except(:email).merge(phone: phone, name: Faker::Name.name)
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    assert User.last.phone == phone
  end

  def test_create_with_existing_fb_user
    user = add_new_user_with_fb_id(@account)
    count = User.count
    params = ticket_params_hash.except(:email).merge(facebook_id: user.fb_profile_id)
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    assert User.count == count
  end

  def test_create_with_existing_twitter
    user = add_new_user_with_twitter_id(@account)
    count = User.count
    params = ticket_params_hash.except(:email).merge(twitter_id: user.twitter_id)
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    assert User.count == count
  end

  def test_create_with_existing_phone
    user = add_new_user_without_email(@account)
    count = User.count
    params = ticket_params_hash.except(:email).merge(phone: user.phone, name: Faker::Name.name)
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    assert User.count == count
  end

  def test_create_with_invalid_custom_fields
    params = ticket_params_hash.merge('custom_fields' => { 'dsfsdf' => 'dsfsdf' })
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('dsfsdf', 'invalid_field')])
  end

  def test_create_with_attachment
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg') 
    params = ticket_params_hash.merge('attachments' => [file, file2])
    stub_const(ApiConstants, "UPLOADED_FILE_TYPE", Rack::Test::UploadedFile) do
      post :create, construct_params({}, params)
    end
    assert_response :created
    response_params = params.except(:tags, :attachments)
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    assert Helpdesk::Ticket.last.attachments.count == 2
  end

  def test_create_with_invalid_attachment_params_format
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    params = ticket_params_hash.merge('attachments' => [1, 2])
    stub_const( ApiConstants, "UPLOADED_FILE_TYPE", Rack::Test::UploadedFile) do
      post :create, construct_params({}, params)
    end
    assert_response :bad_request
    match_json([bad_request_error_pattern('attachments', 'invalid_format')])
  end

  # def test_create_with_custom_fields
  #   put :update, :jsonData => @default_fields.merge(:controller => :ticket_fields)
  # end
end
