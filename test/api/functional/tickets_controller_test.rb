require_relative '../test_helper'

class TicketsControllerTest < ActionController::TestCase
  include Helpers::TicketsHelper
  def controller_params(params = {})
    remove_wrap_params
    request_params.merge(params)
  end

  CUSTOM_FIELDS = %w(number checkbox decimal text paragraph)

  VALIDATABLE_CUSTOM_FIELDS =  %w(number checkbox decimal)

  custom_fields_values = { 'number' => 32_234, 'decimal' => '90.89', 'checkbox' => true, 'text' => Faker::Name.name, 'paragraph' =>  Faker::Lorem.paragraph }
  update_custom_fields_values = { 'number' => 12, 'decimal' => '8900.89',  'checkbox' => false, 'text' => Faker::Name.name, 'paragraph' =>  Faker::Lorem.paragraph }
  custom_fields_values_invalid = { 'number' => '1.90', 'decimal' => 'dd', 'checkbox' => 'iu', 'text' => Faker::Name.name, 'paragraph' =>  Faker::Lorem.paragraph }
  update_custom_fields_values_invalid = { 'number' => '1.89', 'decimal' => 'addsad', 'checkbox' => 'nmbm', 'text' => Faker::Name.name, 'paragraph' =>  Faker::Lorem.paragraph }

  ERROR_PARAMS =  {
    'number' => ['data_type_mismatch', data_type: 'Positive Integer'],
    'decimal' => ['data_type_mismatch', data_type: 'number'],
    'checkbox' => ['data_type_mismatch', data_type: 'Boolean']
  }

  ERROR_REQUIRED_PARAMS  =  {
    'number' => ['data_type_mismatch', data_type: 'Positive Integer'],
    'decimal' => ['required_number'],
    'checkbox' => ['data_type_mismatch', data_type: 'Boolean'],
    'text' => ['missing'],
    'paragraph' => ['missing']
  }

  def wrap_cname(params = {})
    { ticket: params }
  end

  def requester
    user = User.find { |x| x.id != @agent.id && x.helpdesk_agent == false && x.deleted == 0 && x.blocked == 0 } || add_new_user(@account)
    user
  end

  def ticket
    ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
    ticket
  end

  def update_ticket_params_hash
    cc_emails = [Faker::Internet.email, Faker::Internet.email]
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    subject = Faker::Lorem.words(10).join(' ')
    description = Faker::Lorem.paragraph
    @update_group ||= create_group_with_agents(@account, agent_list: [agent.id])
    params_hash = { description: description, cc_emails: cc_emails, subject: subject, priority: 4, status: 3, type: 'Lead',
                    responder_id: agent.id, source: 3, tags: ['update_tag1', 'update_tag2'],
                    due_by: 12.days.since.to_s, fr_due_by: 4.days.since.to_s, group_id: @update_group.id }
    params_hash
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
                    due_by: 14.days.since.to_s, fr_due_by: 1.days.since.to_s, group_id: @create_group.id }
    params_hash
  end

  def test_create
    params = ticket_params_hash
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
  end

  def test_create_with_email
    params = { email: Faker::Internet.email }
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
  end

  def test_create_with_email_config_id
    email_config = create_email_config
    params = { requester_id: requester.id, email_config_id: email_config.id }
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
  end

  def test_create_with_product_id
    product = create_product(email: Faker::Internet.email)
    params = { requester_id: requester.id, product_id: product.id }
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params.merge(email_config_id: product.primary_email_config.id), Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
  end

  def test_create_with_responder_id_not_in_group
    group = create_group(@account)
    params = { requester_id: requester.id, responder_id: @agent.id, group_id: group.id }
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('responder_id', 'not_part_of_group')])
  end

  def test_create_with_product_id_and_email_config_id
    product = create_product(email: Faker::Internet.email)
    product_1 = create_product(email: Faker::Internet.email)
    params = { requester_id: requester.id, product_id: product.id, email_config_id: product_1.primary_email_config.id }
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params.merge(product_id: product_1.id), Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
  end

  def test_create_numericality_invalid
    params = ticket_params_hash.merge(requester_id: 'yu', responder_id: 'io', product_id: 'x', email_config_id: 'x', group_id: 'g')
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('requester_id', 'data_type_mismatch', data_type: 'Positive Integer'),
                bad_request_error_pattern('responder_id', 'data_type_mismatch', data_type: 'Positive Integer'),
                bad_request_error_pattern('product_id', 'data_type_mismatch', data_type: 'Positive Integer'),
                bad_request_error_pattern('email_config_id', 'data_type_mismatch', data_type: 'Positive Integer'),
                bad_request_error_pattern('group_id', 'data_type_mismatch', data_type: 'Positive Integer')])
  end

  def test_create_inclusion_invalid
    params = ticket_params_hash.merge(requester_id: requester.id, priority: 90, status: 56, type: 'jk', source: '89')
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('priority', 'not_included', list: '1,2,3,4'),
                bad_request_error_pattern('status', 'not_included', list: '2,3,4,5,6,7'),
                bad_request_error_pattern('type', 'not_included', list: 'Question,Incident,Problem,Feature Request,Lead'),
                bad_request_error_pattern('source', 'not_included', list: '1,2,3,7,8,9')])
  end

  def test_create_length_invalid
    params = ticket_params_hash.except(:email).merge(name: Faker::Lorem.characters(300), subject: Faker::Lorem.characters(300), phone: Faker::Lorem.characters(300), tags: [Faker::Lorem.characters(300)])
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('name', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('subject', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('phone', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('tags', 'is too long (maximum is 255 characters)')])
    assert_response :bad_request
  end

  def test_create_length_valid_with_trailing_spaces
    params = ticket_params_hash.except(:email).merge(name: Faker::Lorem.characters(20) + white_space, subject: Faker::Lorem.characters(20) + white_space, phone: Faker::Lorem.characters(20) + white_space, tags: [Faker::Lorem.characters(20) + white_space])
    post :create, construct_params({}, params)
    assert_response :created
    params[:tags].each(&:strip!)
    result = params.each { |x, y| y.strip! if [:name, :subject, :phone].include?(x) }
    match_json(ticket_pattern(result, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
  end

  def test_create_length_invalid_twitter_id
    params = ticket_params_hash.except(:email).merge(twitter_id: Faker::Lorem.characters(300))
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('twitter_id', 'is too long (maximum is 255 characters)')])
    assert_response :bad_request
  end

  def test_create_length_valid_twitter_id_with_trailing_spaces
    params = ticket_params_hash.except(:email).merge(twitter_id: Faker::Lorem.characters(20) + white_space)
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params.each { |x, y| y.strip! if [:twitter_id].include?(x) }, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
  end

  def test_create_length_invalid_email
    params = ticket_params_hash.merge(email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(300)}.com")
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('email', 'is too long (maximum is 255 characters)')])
    assert_response :bad_request
  end

  def test_create_length_valid_email_with_trailing_spaces
    params = ticket_params_hash.merge(email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(20)}.com" + white_space)
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params.each { |x, y| y.strip! if [:email].include?(x) }, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
  end

  def test_create_presence_requester_id_invalid
    params = ticket_params_hash.except(:email)
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('requester_id', 'requester_id_mandatory')])
  end

  def test_create_presence_name_invalid
    params = ticket_params_hash.except(:email).merge(phone: Faker::PhoneNumber.phone_number)
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('name', 'phone_mandatory')])
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
    match_json([bad_request_error_pattern('cc_emails', 'data_type_mismatch', data_type: 'Array'),
                bad_request_error_pattern('tags', 'data_type_mismatch', data_type: 'Array'),
                bad_request_error_pattern('custom_fields', 'data_type_mismatch', data_type: 'key/value pair')])
  end

  def test_create_date_time_invalid
    params = ticket_params_hash.merge(due_by: '7/7669/0', fr_due_by: '7/9889/0')
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('due_by', 'is not a date'),
                bad_request_error_pattern('fr_due_by', 'is not a date')])
  end

  def test_create_with_due_by_without_fr_due_by
    params = ticket_params_hash.except(:due_by, :fr_due_by).merge(due_by: 12.days.since.to_s)
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('fr_due_by', 'Should not be blank if due_by is given')])
  end

  def test_create_without_due_by_with_fr_due_by
    params = ticket_params_hash.except(:due_by, :fr_due_by).merge(fr_due_by: 12.days.since.to_s)
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('due_by', 'Should not be blank if fr_due_by is given')])
  end

  def test_create_with_due_by_and_fr_due_by
    params = ticket_params_hash
    Helpdesk::Ticket.any_instance.expects(:update_dueby).never
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
  end

  def test_create_without_due_by_and_fr_due_by
    params = ticket_params_hash.except(:fr_due_by, :due_by)
    Helpdesk::Ticket.any_instance.expects(:update_dueby).once
    post :create, construct_params({}, params)
    assert_response :created
  end

  def test_create_with_invalid_due_by_and_cc_emails_count
    cc_emails = []
    51.times do
      cc_emails << Faker::Internet.email
    end
    params = ticket_params_hash.merge(due_by: 30.days.ago.to_s, cc_emails: cc_emails)
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('cc_emails', 'max_count_exceeded', max_count: "#{TicketConstants::MAX_EMAIL_COUNT}"),
                bad_request_error_pattern('due_by', 'start_time_lt_now')])
  end

  def test_create_invalid_model
    user = add_new_user(@account)
    user.update_attribute(:blocked, true)
    cc_emails = []
    51.times do
      cc_emails << Faker::Internet.email
    end
    params = ticket_params_hash.except(:email).merge(group_id: 89_089, product_id: 9090, email_config_id: 89_789, responder_id: 8987, requester_id: user.id)
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('group_id', "can't be blank"),
                bad_request_error_pattern('responder_id', "can't be blank"),
                bad_request_error_pattern('email_config_id', "can't be blank"),
                bad_request_error_pattern('requester_id', 'user_blocked')])
  end

  def test_create_invalid_user_id
    params = ticket_params_hash.except(:email).merge(requester_id: 898_999)
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('requester_id', 'should be a valid email address')])
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
    match_json([bad_request_error_pattern('requester_id', 'requester_id_mandatory')])
  end

  def test_create_returns_location_header
    params = ticket_params_hash
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    result = parse_response(@response.body)
    assert_equal true, response.headers.include?('Location')
    assert_equal "http://#{@request.host}/api/v2/tickets/#{result['ticket_id']}", response.headers['Location']
  end

  def test_create_with_existing_user
    params = ticket_params_hash.except(:email).merge(requester_id: requester.id)
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
  end

  def test_create_with_new_twitter_user
    params = ticket_params_hash.except(:email).merge(twitter_id: '@test')
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    assert User.last.twitter_id == '@test'
  end

  def test_create_with_new_phone_user
    phone = Faker::PhoneNumber.phone_number
    params = ticket_params_hash.except(:email).merge(phone: phone, name: Faker::Name.name)
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    assert User.last.phone == phone
  end

  def test_create_with_new_fb_user
    params = ticket_params_hash.except(:email).merge(facebook_id:  Faker::Name.name)
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('requester_id', "can't be blank")])
  end

  def test_create_with_existing_fb_user
    user = add_new_user_with_fb_id(@account)
    count = User.count
    params = ticket_params_hash.except(:email).merge(facebook_id: user.fb_profile_id)
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    assert User.count == count
  end

  def test_create_with_existing_twitter
    user = add_new_user_with_twitter_id(@account)
    count = User.count
    params = ticket_params_hash.except(:email).merge(twitter_id: user.twitter_id)
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    assert User.count == count
  end

  def test_create_with_existing_phone
    user = add_new_user_without_email(@account)
    count = User.count
    params = ticket_params_hash.except(:email).merge(phone: user.phone, name: Faker::Name.name)
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    assert User.count == count
  end

  def test_create_with_existing_email
    user = add_new_user(@account)
    count = User.count
    params = ticket_params_hash.except(:email).merge(email: user.email)
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
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({}, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response :created
    response_params = params.except(:tags, :attachments)
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    assert Helpdesk::Ticket.last.attachments.count == 2
  end

  def test_create_with_invalid_attachment_params_format
    params = ticket_params_hash.merge('attachments' => [1, 2])
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('attachments', 'data_type_mismatch', data_type: 'format')])
  end

  def test_attachment_invalid_size_create
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(20_000_000)
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    params = ticket_params_hash.merge('attachments' => [file])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({}, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response :bad_request
    match_json([bad_request_error_pattern('attachments', 'invalid_size', max_size: '15 MB')])
  end

  def test_attachment_invalid_size_update
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    params = update_ticket_params_hash.merge('attachments' => [file])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    attachments = [mock('attachment')]
    attachments.stubs(:sum).returns(20_000_000)
    Helpdesk::Ticket.any_instance.stubs(:attachments).returns(attachments)
    put :update, construct_params({ id: Helpdesk::Ticket.first.id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response :bad_request
    match_json([bad_request_error_pattern('attachments', 'invalid_size', max_size: '15 MB')])
  end

  def test_create_with_nested_custom_fields
    create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia', "state_#{@account.id}" => 'Queensland', "city_#{@account.id}" => 'Brisbane' })
    post :create, construct_params({}, params)
    assert_response :created
    t = Helpdesk::Ticket.find_by_subject(params[:subject])
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
  end

  def test_create_with_nested_custom_fields_with_invalid_first
    create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'uyiyiuy' })
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("country_#{@account.id}", 'not_included', list: 'Australia,USA')])
  end

  def test_create_with_nested_custom_fields_with_invalid_first_children_valid
    create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'uyiyiuy', "state_#{@account.id}" => 'Queensland', "city_#{@account.id}" => 'Brisbane' })
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("country_#{@account.id}", 'not_included', list: 'Australia,USA')])
  end

  def test_create_with_nested_custom_fields_with_invalid_first_children_invalid
    create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'uyiyiuy', "state_#{@account.id}" => 'ss', "city_#{@account.id}" => 'ss' })
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("country_#{@account.id}", 'not_included', list: 'Australia,USA')])
  end

  def test_create_with_nested_custom_fields_with_valid_first_invalid_second_valid_third
    create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia', "state_#{@account.id}" => 'hjhj', "city_#{@account.id}" => 'Brisbane' })
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("state_#{@account.id}", 'not_included', list: 'New South Wales,Queensland')])
  end

  def test_create_with_nested_custom_fields_with_valid_first_invalid_second_without_third
    create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia', "state_#{@account.id}" => 'hjhj' })
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("state_#{@account.id}", 'not_included', list: 'New South Wales,Queensland')])
  end

  def test_create_with_nested_custom_fields_with_valid_first_invalid_second_without_third_invalid_third
    create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia', "state_#{@account.id}" => 'hjhj', "city_#{@account.id}" => 'sfs' })
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("state_#{@account.id}", 'not_included', list: 'New South Wales,Queensland')])
  end

  def test_create_with_nested_custom_fields_with_valid_first_valid_second_invalid_third
    create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia', "state_#{@account.id}" => 'Queensland', "city_#{@account.id}" => 'ddd' })
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("city_#{@account.id}", 'not_included', list: 'Brisbane')])
  end

  def test_create_with_nested_custom_fields_with_valid_first_valid_second_invalid_other_third
    create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia', "state_#{@account.id}" => 'Queensland', "city_#{@account.id}" => 'Sydney' })
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("city_#{@account.id}", 'not_included', list: 'Brisbane')])
  end

  def test_create_with_nested_custom_fields_without_first_with_second_and_third
    create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.merge(custom_fields: { "state_#{@account.id}" => 'Queensland', "city_#{@account.id}" => 'Brisbane' })
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("country_#{@account.id}", 'conditional_not_blank', child: "state_#{@account.id}")])
  end

  def test_create_with_nested_custom_fields_without_first_with_second_only
    create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.merge(custom_fields: { "state_#{@account.id}" => 'Queensland' })
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("country_#{@account.id}", 'conditional_not_blank', child: "state_#{@account.id}")])
  end

  def test_create_with_nested_custom_fields_without_first_with_third_only
    create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.merge(custom_fields: { "city_#{@account.id}" => 'Brisbane' })
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("country_#{@account.id}", 'conditional_not_blank', child: "city_#{@account.id}"),
                bad_request_error_pattern("state_#{@account.id}", 'conditional_not_blank', child: "city_#{@account.id}")])
  end

  def test_create_with_nested_custom_fields_without_second_with_third
    create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia', "city_#{@account.id}" => 'Brisbane' })
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("state_#{@account.id}", 'conditional_not_blank', child: "city_#{@account.id}")])
  end

  def test_create_with_nested_custom_fields_required_without_first_level
    ticket_field = create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash
    ticket_field.update_attribute(:required, true)
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required, false)
    assert_response :bad_request
    match_json([bad_request_error_pattern("country_#{@account.id}", 'required_and_inclusion', list: 'Australia,USA')])
  end

  def test_create_with_nested_custom_fields_required_without_second_level
    ticket_field = create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia' })
    ticket_field.update_attribute(:required, true)
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required, false)
    assert_response :bad_request
    match_json([bad_request_error_pattern("state_#{@account.id}", 'required_and_inclusion', list: 'New South Wales,Queensland')])
  end

  def test_create_with_nested_custom_fields_required_without_third_level
    ticket_field = create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia', "state_#{@account.id}" => 'Queensland' })
    ticket_field.update_attribute(:required, true)
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required, false)
    assert_response :bad_request
    match_json([bad_request_error_pattern("city_#{@account.id}", 'required_and_inclusion', list: 'Brisbane')])
  end

  def test_create_with_nested_custom_fields_required_for_closure_without_first_level
    ticket_field = create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4)
    ticket_field.update_attribute(:required_for_closure, true)
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response :bad_request
    match_json([bad_request_error_pattern("country_#{@account.id}", 'required_and_inclusion', list: 'Australia,USA')])
  end

  def test_create_with_nested_custom_fields_required_for_closure_without_second_level
    ticket_field = create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4, custom_fields: { "country_#{@account.id}" => 'Australia' })
    ticket_field.update_attribute(:required_for_closure, true)
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response :bad_request
    match_json([bad_request_error_pattern("state_#{@account.id}", 'required_and_inclusion', list: 'New South Wales,Queensland')])
  end

  def test_create_with_nested_custom_fields_required_for_closure_without_third_level
    ticket_field = create_dependent_custom_field(%w(Country State City))
    params = ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4, custom_fields: { "country_#{@account.id}" => 'Australia', "state_#{@account.id}" => 'Queensland' })
    ticket_field.update_attribute(:required_for_closure, true)
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response :bad_request
    match_json([bad_request_error_pattern("city_#{@account.id}", 'required_and_inclusion', list: 'Brisbane')])
  end

  def test_create_with_custom_dropdown
    create_custom_field_dropdown('movies', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
    params = ticket_params_hash.merge(custom_fields: { "movies_#{@account.id}" => 'Pursuit of Happiness' })
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
  end

  def test_create_with_custom_dropdown_invalid
    params = ticket_params_hash.merge(custom_fields: { "movies_#{@account.id}" => 'fdfdfdffdfdfdffdf' })
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("movies_#{@account.id}", 'not_included', list: 'Get Smart,Pursuit of Happiness,Armaggedon')])
  end

  def test_create_with_custom_dropdown_required
    ticket_field = create_custom_field_dropdown('movies', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
    ticket_field.update_attribute(:required, true)
    params = ticket_params_hash
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required, false)
    assert_response :bad_request
    match_json([bad_request_error_pattern("movies_#{@account.id}", 'required_and_inclusion', list: 'Get Smart,Pursuit of Happiness,Armaggedon')])
  end

  def test_create_with_custom_dropdown_required_for_closure
    ticket_field = create_custom_field_dropdown('movies', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
    ticket_field.update_attribute(:required_for_closure, true)
    params = ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4)
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response :bad_request
    match_json([bad_request_error_pattern("movies_#{@account.id}", 'required_and_inclusion', list: 'Get Smart,Pursuit of Happiness,Armaggedon')])
  end

  def test_create_with_custom_dropdown_required_for_closure_without_status_closed
    ticket_field = create_custom_field_dropdown('movies', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
    ticket_field.update_attribute(:required_for_closure, true)
    params = ticket_params_hash
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
  end

  def test_create_notify_cc_emails
    params = ticket_params_hash
    controller.class.any_instance.expects(:notify_cc_people).once
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
  end

  def test_create_with_single_line_text_length_invalid
    ticket_field = create_custom_field('test_custom_text', 'text')
    params = ticket_params_hash.merge(custom_fields: { "test_custom_text_#{@account.id}" => Faker::Lorem.characters(300) })
    post :create, construct_params({}, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("test_custom_text_#{@account.id}", 'is too long (maximum is 255 characters)')])
  end

  def test_create_with_single_line_text_trailing_spaces
    ticket_field = create_custom_field('test_custom_text', 'text')
    params = ticket_params_hash.merge(custom_fields: { "test_custom_text_#{@account.id}" => Faker::Lorem.characters(20) + white_space })
    post :create, construct_params({}, params)
    assert_response :created
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
  end

  CUSTOM_FIELDS.each do |custom_field|
    define_method("test_create_with_custom_#{custom_field}") do
      ticket_field = create_custom_field("test_custom_#{custom_field}", custom_field)
      params = ticket_params_hash.merge(custom_fields: { "test_custom_#{custom_field}_#{@account.id}" => custom_fields_values[custom_field] })
      post :create, construct_params({}, params)
      assert_response :created
      match_json(ticket_pattern(params, Helpdesk::Ticket.last))
      match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    end

    define_method("test_create_with_custom_#{custom_field}_required_for_closure_with_status_closed") do
      ticket_field = create_custom_field("test_custom_#{custom_field}", custom_field)
      params = ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 5)
      ticket_field.update_attribute(:required_for_closure, true)
      post :create, construct_params({}, params)
      ticket_field.update_attribute(:required_for_closure, false)
      assert_response :bad_request
      match_json([bad_request_error_pattern("test_custom_#{custom_field}_#{@account.id}", *(ERROR_REQUIRED_PARAMS[custom_field]))])
    end

    define_method("test_create_with_custom_#{custom_field}_required_for_closure_with_status_resolved") do
      ticket_field = create_custom_field("test_custom_#{custom_field}", custom_field)
      params = ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4)
      ticket_field.update_attribute(:required_for_closure, true)
      post :create, construct_params({}, params)
      ticket_field.update_attribute(:required_for_closure, false)
      assert_response :bad_request
      match_json([bad_request_error_pattern("test_custom_#{custom_field}_#{@account.id}", *(ERROR_REQUIRED_PARAMS[custom_field]))])
    end

    define_method("test_create_with_custom_#{custom_field}_required") do
      ticket_field = create_custom_field("test_custom_#{custom_field}", custom_field)
      params = ticket_params_hash
      ticket_field.update_attribute(:required, true)
      post :create, construct_params({}, params)
      ticket_field.update_attribute(:required, false)
      assert_response :bad_request
      match_json([bad_request_error_pattern("test_custom_#{custom_field}_#{@account.id}", *(ERROR_REQUIRED_PARAMS[custom_field]))])
    end

    define_method("test_create_with_custom_#{custom_field}_invalid") do
      ticket_field = create_custom_field("test_custom_#{custom_field}", custom_field)
      params = ticket_params_hash.merge(custom_fields: { "test_custom_#{custom_field}_#{@account.id}" => custom_fields_values_invalid[custom_field] })
      post :create, construct_params({}, params)
      assert_response :bad_request
      match_json([bad_request_error_pattern("test_custom_#{custom_field}_#{@account.id}", *(ERROR_PARAMS[custom_field]))])
    end if VALIDATABLE_CUSTOM_FIELDS.include?(custom_field)

    define_method("test_update_with_custom_#{custom_field}") do
      ticket_field = create_custom_field("test_custom_#{custom_field}", custom_field)
      params_hash = update_ticket_params_hash.merge(custom_fields: { "test_custom_#{custom_field}_#{@account.id}" => update_custom_fields_values[custom_field] })
      t = ticket
      put :update, construct_params({ id: t.display_id }, params_hash)
      assert_response :success
      match_json(ticket_pattern(params_hash, t.reload))
      match_json(ticket_pattern({}, t.reload))
    end

    define_method("test_update_with_custom_#{custom_field}_invalid") do
      ticket_field = create_custom_field("test_custom_#{custom_field}", custom_field)
      params_hash = update_ticket_params_hash.merge(custom_fields: { "test_custom_#{custom_field}_#{@account.id}" => update_custom_fields_values_invalid[custom_field] })
      t = ticket
      put :update, construct_params({ id: t.display_id }, params_hash)
      assert_response :bad_request
      match_json([bad_request_error_pattern("test_custom_#{custom_field}_#{@account.id}", *(ERROR_PARAMS[custom_field]))])
    end if VALIDATABLE_CUSTOM_FIELDS.include?(custom_field)

    define_method("test_update_with_custom_#{custom_field}_required_for_closure_with_status_closed") do
      ticket_field = create_custom_field("test_custom_#{custom_field}", custom_field)
      params_hash = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 5)
      t = ticket
      ticket_field.update_attribute(:required_for_closure, true)
      put :update, construct_params({ id: t.display_id }, params_hash)
      ticket_field.update_attribute(:required_for_closure, false)
      assert_response :bad_request
      match_json([bad_request_error_pattern("test_custom_#{custom_field}_#{@account.id}", *(ERROR_REQUIRED_PARAMS[custom_field]))])
    end

    define_method("test_update_with_custom_#{custom_field}_required_for_closure_with_status_resolved") do
      ticket_field = create_custom_field("test_custom_#{custom_field}", custom_field)
      params_hash = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4)
      t = ticket
      ticket_field.update_attribute(:required_for_closure, true)
      put :update, construct_params({ id: t.display_id }, params_hash)
      ticket_field.update_attribute(:required_for_closure, false)
      assert_response :bad_request
      match_json([bad_request_error_pattern("test_custom_#{custom_field}_#{@account.id}", *(ERROR_REQUIRED_PARAMS[custom_field]))])
    end

    define_method("test_update_with_custom_#{custom_field}_required") do
      ticket_field = create_custom_field("test_custom_#{custom_field}", custom_field)
      params_hash = update_ticket_params_hash
      t = ticket
      ticket_field.update_attribute(:required, true)
      put :update, construct_params({ id: t.display_id }, params_hash)
      ticket_field.update_attribute(:required, false)
      assert_response :bad_request
      match_json([bad_request_error_pattern("test_custom_#{custom_field}_#{@account.id}", *(ERROR_REQUIRED_PARAMS[custom_field]))])
    end
  end

  def test_update_with_attachment
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = update_ticket_params_hash.merge('attachments' => [file, file2])
    t = ticket
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    put :update, construct_params({ id: t.display_id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response :success
    response_params = params.except(:tags, :attachments)
    match_json(ticket_pattern(params, t.reload))
    match_json(ticket_pattern({}, t.reload))
    assert ticket.attachments.count == 2
  end

  def test_update_with_invalid_attachment_params_format
    params = update_ticket_params_hash.merge('attachments' => [1, 2])
    put :update, construct_params({ id: ticket.display_id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('attachments', 'data_type_mismatch', data_type: 'format')])
  end

  def test_update
    params_hash = update_ticket_params_hash
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_invalid_due_by_and_cc_emails_count
    cc_emails = []
    51.times do
      cc_emails << Faker::Internet.email
    end
    params = update_ticket_params_hash.merge(due_by: 30.days.ago.to_s, cc_emails: cc_emails)
    t = ticket
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('cc_emails', 'max_count_exceeded', max_count: "#{TicketConstants::MAX_EMAIL_COUNT}"),
                bad_request_error_pattern('due_by', 'start_time_lt_now')])
  end

  def test_update_without_due_by
    params = update_ticket_params_hash
    t = ticket
    t.update_attribute(:due_by, (t.created_at - 10.days).to_s)
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :success
  end

  def test_update_invalid_model
    user = add_new_user(@account)
    user.update_attribute(:blocked, true)
    cc_emails = []
    51.times do
      cc_emails << Faker::Internet.email
    end
    params = update_ticket_params_hash.except(:email).merge(group_id: 89_089, product_id: 9090, email_config_id: 89_789, responder_id: 8987, requester_id: user.id)
    t = ticket
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('group_id', "can't be blank"),
                bad_request_error_pattern('responder_id', "can't be blank"),
                bad_request_error_pattern('email_config_id', "can't be blank"),
                bad_request_error_pattern('requester_id', 'user_blocked')])
  end

  def test_update_with_responder_id_not_in_group
    group = create_group(@account)
    params = { responder_id: @agent.id, group_id: group.id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern('responder_id', 'not_part_of_group')])
  end

  def test_update_with_email_config_id
    email_config = create_email_config
    params_hash = { email_config_id: email_config.id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_product_id
    product = create_product(email: Faker::Internet.email)
    params_hash = { product_id: product.id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash.merge(email_config_id: product.primary_email_config.id), t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_product_id_and_diff_email_config_id
    product = create_product(email: Faker::Internet.email)
    product_1 = create_product(email: Faker::Internet.email)
    params_hash = { product_id: product.id, email_config_id: product_1.primary_email_config.id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash.merge(email_config_id: product.primary_email_config.id), t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_product_id_and_same_email_config_id
    product = create_product(email: Faker::Internet.email)
    email_config = create_email_config(product_id: product.id)
    params_hash = { product_id: product.id, email_config_id: email_config.id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_notifying_cc_email
    params_hash = update_ticket_params_hash
    t =  Helpdesk::Ticket.find do |ticket|
      ticket.cc_email && ticket.cc_email[:cc_emails].present? && ticket.deleted == 0 && ticket.spam == 0
    end
    if t.nil?
      t = ticket
      cc_emails = [Faker::Internet.email, Faker::Internet.email]
      t.cc_email = { cc_emails: cc_emails, reply_cc: cc_emails, fwd_emails: [] }
      t.save
      t.reload
    end
    controller.class.any_instance.expects(:notify_cc_people).once
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
  end

  def test_update_with_low_priority
    params_hash = { priority: 1 }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    assert t.reload.priority == 1
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_type
    params_hash = { type: 'Incident' }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    assert t.reload.ticket_type == 'Incident'
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_subject
    subject = Faker::Lorem.words(10).join(' ')
    params_hash = { subject: subject }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    assert t.reload.subject == subject
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_description
    description =  Faker::Lorem.paragraph
    params_hash = { description: description }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    assert t.reload.description == description
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_responder_id_in_group
    responder_id = add_test_agent(@account).id
    params_hash = { responder_id: responder_id }
    t = ticket
    group = t.group
    group.agent_groups.create(user_id: responder_id, group_id: group.id)
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    assert t.reload.responder_id == responder_id
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_requester_id
    requester_id = add_new_user(@account).id
    params_hash = { requester_id: requester_id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    assert t.reload.requester_id == requester_id
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_group_id
    t = ticket
    group_id = create_group_with_agents(@account, agent_list: [t.responder_id]).id
    params_hash = { group_id: group_id }
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    assert t.reload.group_id == group_id
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_source
    params_hash = { source: 2 }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    assert t.reload.source == 2
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_cc_emails
    cc_emails = [Faker::Internet.email, Faker::Internet.email]
    params_hash = { cc_emails: cc_emails }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    assert t.reload.cc_email[:cc_emails] == cc_emails
    assert t.reload.cc_email[:reply_cc] == cc_emails
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_tags
    tags = [Faker::Name.name, Faker::Name.name]
    params_hash = { tags: tags }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    assert t.reload.tag_names == tags
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_closed_status
    params_hash = { status: 5 }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    assert t.reload.status == 5
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_resolved_status
    params_hash = { status: 4 }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    assert t.reload.status == 4
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_new_email_without_nil_requester_id
    params_hash = update_ticket_params_hash.merge(email:  Faker::Internet.email)
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
    assert User.count == count
  end

  def test_update_with_new_twitter_id_without_nil_requester_id
    params_hash = update_ticket_params_hash.merge(twitter_id:  "@#{Faker::Name.name}")
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
    assert User.count == count
  end

  def test_update_with_new_phone_without_nil_requester_id
    params_hash = update_ticket_params_hash.merge(phone: Faker::PhoneNumber.phone_number, name:  Faker::Name.name)
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
    assert User.count == count
  end

  def test_update_with_new_email_with_nil_requester_id
    email = Faker::Internet.email
    params_hash = update_ticket_params_hash.merge(email: email, requester_id: nil)
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash.merge(requester_id: User.last.id), t.reload))
    match_json(ticket_pattern({}, t.reload))
    assert User.count == (count + 1)
    assert User.find(t.reload.requester_id).email == email
  end

  def test_update_with_new_twitter_id_with_nil_requester_id
    twitter_id = "@#{Faker::Name.name}"
    params_hash = update_ticket_params_hash.merge(twitter_id: twitter_id, requester_id: nil)
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash.merge(requester_id: User.last.id), t.reload))
    match_json(ticket_pattern({}, t.reload))
    assert User.count == (count + 1)
    assert User.find(t.reload.requester_id).twitter_id == twitter_id
  end

  def test_update_with_new_phone_with_nil_requester_id
    phone = Faker::PhoneNumber.phone_number
    name = Faker::Name.name
    params_hash = update_ticket_params_hash.merge(phone: phone, name: name, requester_id: nil)
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash.merge(requester_id: User.last.id), t.reload))
    match_json(ticket_pattern({}, t.reload))
    assert User.count == (count + 1)
    assert User.find(t.reload.requester_id).phone == phone
    assert User.find(t.reload.requester_id).name == name
  end

  def test_update_with_due_by_and_fr_due_by
    t = create_ticket(ticket_params_hash.except(:fr_due_by, :due_by))
    previous_fr_due_by = t.frDueBy
    previous_due_by = t.due_by
    params_hash = { fr_due_by: 2.hours.since.to_s, due_by: 100.days.since.to_s }
    Helpdesk::Ticket.any_instance.expects(:update_dueby).at_most_once
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    assert t.reload.due_by != previous_due_by
    assert t.reload.frDueBy != previous_fr_due_by
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_due_by
    t = create_ticket(ticket_params_hash.except(:fr_due_by, :due_by))
    previous_due_by = t.due_by
    params_hash = { due_by: 100.days.since.to_s }
    Helpdesk::Ticket.any_instance.expects(:update_dueby).at_most_once
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    assert t.reload.due_by != previous_due_by
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_fr_due_by
    t = create_ticket(ticket_params_hash.except(:fr_due_by, :due_by))
    previous_fr_due_by = t.frDueBy
    params_hash = { fr_due_by: 2.hours.since.to_s }
    Helpdesk::Ticket.any_instance.expects(:update_dueby).at_most_once
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    assert t.reload.frDueBy != previous_fr_due_by
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_new_fb_id
    t = ticket
    params_hash = update_ticket_params_hash.merge(facebook_id: Faker::Name.name, requester_id: nil)
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('requester_id', "can't be blank")])
  end

  def test_update_with_status_resolved_and_due_by
    t = ticket
    params_hash = { status: 4, due_by: 12.days.since.to_s, fr_due_by: 4.days.since.to_s }
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('due_by', 'invalid_field'),
                bad_request_error_pattern('fr_due_by', 'invalid_field')])
  end

  def test_update_with_status_closed_and_due_by
    t = ticket
    params_hash = { status: 5, due_by: 12.days.since.to_s, fr_due_by: 4.days.since.to_s }
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('due_by', 'invalid_field'),
                bad_request_error_pattern('fr_due_by', 'invalid_field')])
  end

  def test_update_numericality_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: 'yu', responder_id: 'io', product_id: 'x', email_config_id: 'x', group_id: 'g')
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('requester_id', 'data_type_mismatch', data_type: 'Positive Integer'),
                bad_request_error_pattern('responder_id', 'data_type_mismatch', data_type: 'Positive Integer'),
                bad_request_error_pattern('product_id', 'data_type_mismatch', data_type: 'Positive Integer'),
                bad_request_error_pattern('email_config_id', 'data_type_mismatch', data_type: 'Positive Integer'),
                bad_request_error_pattern('group_id', 'data_type_mismatch', data_type: 'Positive Integer')])
  end

  def test_update_inclusion_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: requester.id, priority: 90, status: 56, type: 'jk', source: '89')
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('priority', 'not_included', list: '1,2,3,4'),
                bad_request_error_pattern('status', 'not_included', list: '2,3,4,5,6,7'),
                bad_request_error_pattern('type', 'not_included', list: 'Question,Incident,Problem,Feature Request,Lead'),
                bad_request_error_pattern('source', 'not_included', list: '1,2,3,7,8,9')])
  end

  def test_update_length_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(name: Faker::Lorem.characters(300), requester_id: nil, subject: Faker::Lorem.characters(300), phone: Faker::Lorem.characters(300), tags: [Faker::Lorem.characters(300)])
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json([bad_request_error_pattern('name', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('subject', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('phone', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('tags', 'is too long (maximum is 255 characters)')])
    assert_response :bad_request
  end

  def test_update_length_valid_with_trailing_spaces
    t = ticket
    params_hash = update_ticket_params_hash.merge(name: Faker::Lorem.characters(20) + white_space, requester_id: nil, subject: Faker::Lorem.characters(20) + white_space, phone: Faker::Lorem.characters(20) + white_space, tags: [Faker::Lorem.characters(20) + white_space])
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    params_hash[:tags].each(&:strip!)
    result = params_hash.each { |x, y| y.strip! if [:name, :subject, :phone].include?(x) }
    match_json(ticket_pattern(result, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_length_invalid_twitter_id
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: nil, twitter_id: Faker::Lorem.characters(300))
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json([bad_request_error_pattern('twitter_id', 'is too long (maximum is 255 characters)')])
    assert_response :bad_request
  end

  def test_update_length_valid_twitter_id_with_trailing_space
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: nil, twitter_id: Faker::Lorem.characters(20) + white_space)
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash.each { |x, y| y.strip! if [:twitter_id].include?(x) }, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_length_invalid_email
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: nil, email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(300)}.com")
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json([bad_request_error_pattern('email', 'is too long (maximum is 255 characters)')])
    assert_response :bad_request
  end

  def test_update_length_valid_email_with_trailing_space
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: nil, email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(20)}.com" + white_space)
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash.each { |x, y| y.strip! if [:email].include?(x) }, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_presence_requester_id_invalid
    t = ticket
    params_hash = update_ticket_params_hash.except(:email).merge(requester_id: nil)
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('requester_id', 'requester_id_mandatory')])
  end

  def test_update_presence_name_invalid
    t = ticket
    params_hash = update_ticket_params_hash.except(:email).merge(phone: Faker::PhoneNumber.phone_number, requester_id: nil)
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('name', 'phone_mandatory')])
  end

  def test_update_email_format_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(email: 'test@', requester_id: nil)
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('email', 'is not a valid email')])
  end

  def test_update_data_type_invalid
    t = ticket
    cc_emails = "#{Faker::Internet.email},#{Faker::Internet.email}"
    params_hash = update_ticket_params_hash.merge(tags: 'tag1,tag2', custom_fields: [])
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('tags', 'data_type_mismatch', data_type: 'Array'),
                bad_request_error_pattern('custom_fields', 'data_type_mismatch', data_type: 'key/value pair')])
  end

  def test_update_date_time_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(due_by: '7/7669/0', fr_due_by: '7/9889/0')
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('due_by', 'is not a date'),
                bad_request_error_pattern('fr_due_by', 'is not a date')])
  end

  def test_update_extra_params_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(junk: 'test')
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('junk', 'invalid_field')])
  end

  def test_update_empty_params
    t = ticket
    params_hash = {}
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :bad_request
    match_json(request_error_pattern('missing_params'))
  end

  def test_update_with_existing_fb_user
    t = ticket
    user = add_new_user_with_fb_id(@account)
    params_hash = update_ticket_params_hash.except(:email).merge(facebook_id: user.fb_profile_id, requester_id: nil)
    count = User.count
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
    assert User.count == count
  end

  def test_update_with_existing_twitter
    user = add_new_user_with_twitter_id(@account)
    params_hash = update_ticket_params_hash.except(:email).merge(twitter_id: user.twitter_id, requester_id: nil)
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
    assert User.count == count
    assert User.find(t.reload.requester_id).twitter_id == user.twitter_id
  end

  def test_update_with_existing_phone
    t = ticket
    user = add_new_user_without_email(@account)
    params_hash = update_ticket_params_hash.except(:email).merge(phone: user.phone, name: Faker::Name.name, requester_id: nil)
    count = User.count
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
    assert User.count == count
    assert User.find(t.reload.requester_id).phone == user.phone
  end

  def test_update_with_existing_email
    t = ticket
    user = add_new_user(@account)
    params_hash = update_ticket_params_hash.merge(email: user.email, requester_id: nil)
    count = User.count
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :success
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
    assert User.count == count
    assert User.find(t.reload.requester_id).email == user.email
  end

  def test_update_with_invalid_custom_fields
    t = ticket
    params_hash = update_ticket_params_hash.merge('custom_fields' => { 'dsfsdf' => 'dsfsdf' })
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('dsfsdf', 'invalid_field')])
  end

  def test_update_with_nested_custom_fields
    create_dependent_custom_field(%w(Country State City))
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'USA', "state_#{@account.id}" => 'California', "city_#{@account.id}" => 'Burlingame' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :success
    match_json(ticket_pattern(params, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_nested_custom_fields_with_invalid_first
    create_dependent_custom_field(%w(Country State City))
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'uyiyiuy' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("country_#{@account.id}", 'not_included', list: 'Australia,USA')])
  end

  def test_update_with_nested_custom_fields_with_invalid_first_children_valid
    create_dependent_custom_field(%w(Country State City))
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'uyiyiuy', "state_#{@account.id}" => 'Queensland', "city_#{@account.id}" => 'Brisbane' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("country_#{@account.id}", 'not_included', list: 'Australia,USA')])
  end

  def test_update_with_nested_custom_fields_with_invalid_first_children_invalid
    create_dependent_custom_field(%w(Country State City))
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'uyiyiuy', "state_#{@account.id}" => 'ss', "city_#{@account.id}" => 'ss' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("country_#{@account.id}", 'not_included', list: 'Australia,USA')])
  end

  def test_update_with_nested_custom_fields_with_valid_first_invalid_second_valid_third
    create_dependent_custom_field(%w(Country State City))
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia', "state_#{@account.id}" => 'hjhj', "city_#{@account.id}" => 'Brisbane' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("state_#{@account.id}", 'not_included', list: 'New South Wales,Queensland')])
  end

  def test_update_with_nested_custom_fields_with_valid_first_invalid_second_without_third
    create_dependent_custom_field(%w(Country State City))
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia', "state_#{@account.id}" => 'hjhj' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("state_#{@account.id}", 'not_included', list: 'New South Wales,Queensland')])
  end

  def test_update_with_nested_custom_fields_with_valid_first_invalid_second_without_third_invalid_third
    create_dependent_custom_field(%w(Country State City))
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia', "state_#{@account.id}" => 'hjhj', "city_#{@account.id}" => 'sfs' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("state_#{@account.id}", 'not_included', list: 'New South Wales,Queensland')])
  end

  def test_update_with_nested_custom_fields_with_valid_first_valid_second_invalid_third
    create_dependent_custom_field(%w(Country State City))
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia', "state_#{@account.id}" => 'Queensland', "city_#{@account.id}" => 'ddd' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("city_#{@account.id}", 'not_included', list: 'Brisbane')])
  end

  def test_update_with_nested_custom_fields_with_valid_first_valid_second_invalid_other_third
    create_dependent_custom_field(%w(Country State City))
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia', "state_#{@account.id}" => 'Queensland', "city_#{@account.id}" => 'Sydney' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("city_#{@account.id}", 'not_included', list: 'Brisbane')])
  end

  def test_update_with_nested_custom_fields_without_first_with_second_and_third
    create_dependent_custom_field(%w(Country State City))
    t = create_ticket(requester_id: @agent.id, custom_field: { "country_#{@account.id}" => 'Australia' })
    params = update_ticket_params_hash.merge(custom_fields: { "state_#{@account.id}" => 'Queensland', "city_#{@account.id}" => 'Brisbane' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :success
    match_json(ticket_pattern(params, Helpdesk::Ticket.find(t.id)))
    match_json(ticket_pattern({}, Helpdesk::Ticket.find(t.id)))
  end

  def test_update_with_nested_custom_fields_without_first_with_second_only
    create_dependent_custom_field(%w(Country State City))
    t = create_ticket(requester_id: @agent.id, custom_field: { "country_#{@account.id}" => 'Australia' })
    params = update_ticket_params_hash.merge(custom_fields: { "state_#{@account.id}" => 'Queensland' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :success
    match_json(ticket_pattern(params, Helpdesk::Ticket.find(t.id)))
    match_json(ticket_pattern({}, Helpdesk::Ticket.find(t.id)))
  end

  def test_update_with_nested_custom_fields_without_first_with_third_only
    create_dependent_custom_field(%w(Country State City))
    t = create_ticket(requester_id: @agent.id, custom_field: { "country_#{@account.id}" => 'Australia', "state_#{@account.id}" => 'Queensland' })
    params = update_ticket_params_hash.merge(custom_fields: { "city_#{@account.id}" => 'Brisbane' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :success
    match_json(ticket_pattern(params, Helpdesk::Ticket.find(t.id)))
    match_json(ticket_pattern({}, Helpdesk::Ticket.find(t.id)))
  end

  def test_update_with_nested_custom_fields_without_second_with_third
    create_dependent_custom_field(%w(Country State City))
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia', "city_#{@account.id}" => 'Brisbane' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("state_#{@account.id}", 'conditional_not_blank', child: "city_#{@account.id}")])
  end

  def test_update_with_nested_custom_fields_required_without_first_level
    ticket_field = create_dependent_custom_field(%w(Country State City))
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash
    ticket_field.update_attribute(:required, true)
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required, false)
    assert_response :bad_request
    match_json([bad_request_error_pattern("country_#{@account.id}", 'required_and_inclusion', list: 'Australia,USA')])
  end

  def test_update_with_nested_custom_fields_required_without_second_level
    ticket_field = create_dependent_custom_field(%w(Country State City))
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia' })
    ticket_field.update_attribute(:required, true)
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required, false)
    assert_response :bad_request
    match_json([bad_request_error_pattern("state_#{@account.id}", 'required_and_inclusion', list: 'New South Wales,Queensland')])
  end

  def test_update_with_nested_custom_fields_required_without_third_level
    ticket_field = create_dependent_custom_field(%w(Country State City))
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash.merge(custom_fields: { "country_#{@account.id}" => 'Australia', "state_#{@account.id}" => 'Queensland' })
    ticket_field.update_attribute(:required, true)
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required, false)
    assert_response :bad_request
    match_json([bad_request_error_pattern("city_#{@account.id}", 'required_and_inclusion', list: 'Brisbane')])
  end

  def test_update_with_nested_custom_fields_required_for_closure_without_first_level
    ticket_field = create_dependent_custom_field(%w(Country State City))
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4)
    ticket_field.update_attribute(:required_for_closure, true)
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response :bad_request
    match_json([bad_request_error_pattern("country_#{@account.id}", 'required_and_inclusion', list: 'Australia,USA')])
  end

  def test_update_with_nested_custom_fields_required_for_closure_without_second_level
    ticket_field = create_dependent_custom_field(%w(Country State City))
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4, custom_fields: { "country_#{@account.id}" => 'Australia' })
    ticket_field.update_attribute(:required_for_closure, true)
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response :bad_request
    match_json([bad_request_error_pattern("state_#{@account.id}", 'required_and_inclusion', list: 'New South Wales,Queensland')])
  end

  def test_update_with_nested_custom_fields_required_for_closure_without_third_level
    ticket_field = create_dependent_custom_field(%w(Country State City))
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4, custom_fields: { "country_#{@account.id}" => 'Australia', "state_#{@account.id}" => 'Queensland' })
    ticket_field.update_attribute(:required_for_closure, true)
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response :bad_request
    match_json([bad_request_error_pattern("city_#{@account.id}", 'required_and_inclusion', list: 'Brisbane')])
  end

  def test_update_with_custom_dropdown
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { "movies_#{@account.id}" => 'Pursuit of Happiness' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :success
    match_json(ticket_pattern(params, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_custom_dropdown_invalid
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { "movies_#{@account.id}" => 'test' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("movies_#{@account.id}", 'not_included', list: 'Get Smart,Pursuit of Happiness,Armaggedon')])
  end

  def test_update_with_custom_dropdown_required
    t = ticket
    ticket_field = create_custom_field_dropdown('movies', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
    ticket_field.update_attribute(:required, true)
    params = update_ticket_params_hash.merge(custom_fields: { "movies_#{@account.id}" => nil })
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required, false)
    assert_response :bad_request
    match_json([bad_request_error_pattern("movies_#{@account.id}", 'required_and_inclusion', list: 'Get Smart,Pursuit of Happiness,Armaggedon')])
  end

  def test_update_with_custom_dropdown_required_for_closure
    t = ticket
    ticket_field = create_custom_field_dropdown('movies', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
    ticket_field.update_attribute(:required_for_closure, true)
    params = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4, custom_fields: { "movies_#{@account.id}" => nil })
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response :bad_request
    match_json([bad_request_error_pattern("movies_#{@account.id}", 'required_and_inclusion', list: 'Get Smart,Pursuit of Happiness,Armaggedon')])
  end

  def test_update_with_custom_dropdown_required_for_closure_without_status_closed
    t = ticket
    ticket_field = create_custom_field_dropdown('movies', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
    ticket_field.update_attribute(:required_for_closure, true)
    params = update_ticket_params_hash.merge(custom_fields: { "movies_#{@account.id}" => nil })
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response :success
    match_json(ticket_pattern(params, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_single_line_text_length_invalid
    t = ticket
    ticket_field = create_custom_field('test_custom_text', 'text')
    params = update_ticket_params_hash.merge(custom_fields: { "test_custom_text_#{@account.id}" => Faker::Lorem.characters(300) })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :bad_request
    match_json([bad_request_error_pattern("test_custom_text_#{@account.id}", 'is too long (maximum is 255 characters)')])
  end

  def test_update_with_single_line_text_trailing_spaces
    t = ticket
    ticket_field = create_custom_field('test_custom_text', 'text')
    params = update_ticket_params_hash.merge(custom_fields: { "test_custom_text_#{@account.id}" => Faker::Lorem.characters(20) + white_space })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response :success
    match_json(ticket_pattern(params, t.reload))
    match_json(ticket_pattern({}, t.reload))
  end

  def test_destroy
    ticket.update_column(:deleted, false)
    delete :destroy, construct_params(id: ticket.display_id)
    assert_response :no_content
    assert Helpdesk::Ticket.find_by_display_id(ticket.display_id).deleted == true
  end

  def test_destroy_invalid_id
    delete :destroy, construct_params(id: '78798')
    assert_response :not_found
  end

  def test_update_verify_permission_invalid_permission
    User.any_instance.stubs(:has_ticket_permission?).with(ticket).returns(false).at_most_once
    put :update, construct_params({ id: ticket.display_id }, update_ticket_params_hash)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
  end

  def test_update_verify_permission_ticket_trashed
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true).at_most_once
    put :update, construct_params({ id: ticket.display_id }, update_ticket_params_hash)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
  end

  def test_delete_has_ticket_permission_invalid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
    User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
    delete :destroy, construct_params(id: Helpdesk::Ticket.first.display_id)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
  end

  def test_delete_has_ticket_permission_valid
    t = create_ticket(ticket_params_hash)
    User.any_instance.stubs(:can_view_all_tickets?).returns(true).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
    User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
    delete :destroy, construct_params(id: t.display_id)
    assert_response :no_content
  end

  def test_delete_group_ticket_permission_invalid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(true).at_most_once
    User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
    Helpdesk::Ticket.stubs(:group_tickets_permission).returns([]).at_most_once
    delete :destroy, construct_params(id: Helpdesk::Ticket.first.display_id)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
  end

  def test_delete_assigned_ticket_permission_invalid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
    User.any_instance.stubs(:assigned_ticket_permission).returns(true).at_most_once
    Helpdesk::Ticket.stubs(:assigned_tickets_permission).returns([]).at_most_once
    delete :destroy, construct_params(id: ticket.display_id)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
  end

  def test_delete_group_ticket_permission_valid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(true).at_most_once
    User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
    t = create_ticket(ticket_params_hash)
    group = create_group_with_agents(@account, agent_list: [@agent.id])
    t = create_ticket(ticket_params_hash.merge(group_id: group.id))
    delete :destroy, construct_params(id: t.display_id)
    assert_response :no_content
  end

  def test_delete_assigned_ticket_permission_valid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
    User.any_instance.stubs(:assigned_ticket_permission).returns(true).at_most_once
    t = create_ticket(ticket_params_hash)
    Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(@agent.id)
    delete :destroy, construct_params(id: t.display_id)
    assert_response :no_content
    Helpdesk::Ticket.any_instance.unstub(:responder_id)
  end

  def test_restore_extra_params
    ticket.update_column(:deleted, true)
    put :restore, construct_params({ id: ticket.display_id }, test: 1)
    assert_response :bad_request
    match_json [bad_request_error_pattern('test', 'invalid_field')]
  end

  def test_restore_load_object_not_present
    put :restore, construct_params(id: 999)
    assert_response :not_found
    assert_equal ' ', @response.body
  end

  def test_restore_without_privilege
    User.any_instance.stubs(:privilege?).with(:delete_ticket).returns(false).at_most_once
    put :restore, construct_params(id: Helpdesk::Ticket.first.display_id)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
  end

  def test_restore_with_permission
    t = create_ticket
    t.update_column(:deleted, true)
    put :restore, construct_params(id: t.display_id)
    assert_response :no_content
    refute ticket.reload.deleted
  end

  def test_show_object_not_present
    get :show, controller_params(id: 999)
    assert_response :not_found
    assert_equal ' ', @response.body
  end

  def test_show_without_permission
    User.any_instance.stubs(:has_ticket_permission?).returns(false).at_most_once
    get :show, controller_params(id: Helpdesk::Ticket.first.display_id)
    assert_response :forbidden
    match_json(request_error_pattern('access_denied'))
  end

  def test_update_deleted
    ticket.update_column(:deleted, true)
    put :update, construct_params({ id: ticket.display_id }, source: 2)
    assert_response :not_found
    ticket.update_column(:deleted, false)
  end

  def test_detroy_deleted
    ticket.update_column(:deleted, true)
    delete :destroy, construct_params(id: ticket.display_id)
    assert_response :not_found
    ticket.update_column(:deleted, false)
  end

  def test_restore_not_deleted
    ticket.update_column(:deleted, false)
    put :restore, construct_params(id: ticket.display_id)
    assert_response :not_found
  end

  def test_show
    ticket.update_column(:deleted, false)
    get :show, controller_params(id: ticket.display_id)
    assert_response :success
    match_json(ticket_pattern({}, ticket))
  end

  def test_show_with_notes
    ticket.update_column(:deleted, false)
    get :show, controller_params(id: ticket.display_id, include: 'notes')
    assert_response :success
    match_json(ticket_pattern_with_notes({}, ticket))
  end

  def test_show_with_invalid_param_value
    ticket.update_column(:deleted, false)
    get :show, controller_params(id: ticket.display_id, include: 'test')
    assert_response :bad_request
    match_json([bad_request_error_pattern('include', "can't be blank")])
  end

  def test_show_with_invalid_params
    ticket.update_column(:deleted, false)
    get :show, controller_params(id: ticket.display_id, includ: 'test')
    assert_response :bad_request
    match_json([bad_request_error_pattern('includ', 'invalid_field')])
  end

  def test_show_deleted
    ticket.update_column(:deleted, true)
    get :show, controller_params(id: ticket.display_id)
    assert_response :success
    match_json(deleted_ticket_pattern({}, ticket))
    ticket.update_column(:deleted, false)
  end

  def test_index_without_permitted_tickets
    Helpdesk::Ticket.update_all(responder_id: nil)
    get :index, controller_params
    assert_response :success
    response = parse_response @response.body
    assert_equal Helpdesk::Ticket.where(deleted: 0, spam: 0).count, response.size

    Agent.any_instance.stubs(:ticket_permission).returns(3)
    get :index, controller_params
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    Helpdesk::Ticket.where(deleted: 0, spam: 0).first.update_attributes(responder_id: @agent.id)
    get :index, controller_params
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_invalid_sort_params
    get :index, controller_params(order_type: 'test', order_by: 'test')
    assert_response :bad_request
    pattern = [bad_request_error_pattern('order_type', 'not_included', list: 'asc,desc')]
    pattern << bad_request_error_pattern('order_by', 'not_included', list: 'due_by,created_at,updated_at,priority,status')
    match_json(pattern)
  end

  def test_index_with_extra_params
    hash = { filter_name: 'test', company_name: 'test' }
    get :index, controller_params(hash)
    assert_response :bad_request
    pattern = []
    hash.keys.each { |key| pattern << bad_request_error_pattern(key, 'invalid_field') }
    match_json pattern
  end

  def test_index_with_invalid_params
    get :index, controller_params(company_id: 999, requester_id: 999, filter: 'x')
    pattern = [bad_request_error_pattern('filter', 'not_included', list: 'new_and_my_open,watching,spam,deleted')]
    pattern << bad_request_error_pattern('company_id', "can't be blank")
    pattern << bad_request_error_pattern('requester_id', "can't be blank")
    assert_response :bad_request
    match_json pattern
  end

  def test_index_with_monitored_by
    get :index, controller_params(filter: 'watching')
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.count

    subscription = FactoryGirl.build(:subscription, account_id: @account.id,
                                                    ticket_id: Helpdesk::Ticket.first.id,
                                                    user_id: @agent.id)
    subscription.save
    get :index, controller_params(filter: 'watching')
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.count
  end

  def test_index_with_new_and_my_open
    Helpdesk::Ticket.update_all(status: 3)
    Helpdesk::Ticket.first.update_attributes(status: 2, responder_id: @agent.id,
                                             deleted: false, spam: false)
    get :index, controller_params(filter: 'new_and_my_open')
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_spam
    get :index, controller_params(filter: 'spam')
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    Helpdesk::Ticket.first.update_attributes(spam: true)
    get :index, controller_params(filter: 'spam')
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_deleted
    tkts = Helpdesk::Ticket.select { |x| x.deleted && !x.schema_less_ticket.boolean_tc02 }
    get :index, controller_params(filter: 'deleted')
    assert_response :success
    pattern = []
    tkts.each { |tkt| pattern << index_deleted_ticket_pattern(tkt) }
    match_json(pattern)
  end

  def test_index_with_requester
    Helpdesk::Ticket.update_all(requester_id: User.first.id)
    create_ticket(requester_id: User.last.id)
    get :index, controller_params(requester_id: User.last.id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.count
    set_wrap_params
  end

  def test_index_with_filter_and_requester_email
    user = add_new_user(@account)

    get :index, controller_params(filter: 'new_and_my_open', email: user.email)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.count

    Helpdesk::Ticket.where(deleted: 0, spam: 0).first.update_attributes(requester_id: user.id, status: 2)
    get :index, controller_params(filter: 'new_and_my_open', email: user.email)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.count
  end

  def test_index_with_company
    company = create_company
    user = User.first
    user.update_attributes(customer_id: company.id)
    get :index, controller_params(company_id: company.id)
    assert_response :success

    tkts = Helpdesk::Ticket.where(requester_id: user.id)
    pattern = tkts.map { |tkt| index_ticket_pattern(tkt) }
    match_json(pattern)
  end

  def test_index_with_filter_and_requester
    user = add_new_user(@account)
    Helpdesk::Ticket.update_all(requester_id: user.id)
    get :index, controller_params(filter: 'new_and_my_open', requester_id: User.first.id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.count

    Helpdesk::Ticket.where(deleted: 0, spam: 0).first.update_attributes(requester_id: User.first.id, status: 2)
    get :index, controller_params(filter: 'new_and_my_open', requester_id: User.first.id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.count
  end

  def test_index_with_filter_and_company
    Helpdesk::Ticket.update_all(status: 3)
    get :index, controller_params(filter: 'new_and_my_open', company_id: Company.first.id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.count

    user_id = Company.first.users.map(&:id).first
    tkt = Helpdesk::Ticket.first
    tkt.update_attributes(status: 2, requester_id: user_id, responder_id: nil)
    get :index, controller_params(filter: 'new_and_my_open', company_id: Company.first.id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.count
  end

  def test_index_with_company_and_requester
    company = Company.first
    user1 = User.first
    user2 = User.first(2).last
    user1.update_column(:customer_id, company.id)
    user1.reload

    expected_size = @account.tickets.where(deleted: 0, spam: 0, requester_id: user1.id).count
    get :index, controller_params(company_id: company.id, requester_id: user1.id)
    assert_response :success
    response = parse_response @response.body
    assert_equal expected_size, response.size

    user2.update_column(:customer_id, nil)
    get :index, controller_params(company_id: company.id, requester_id: user2.id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size
  end

  def test_index_with_requester_filter_company
    remove_wrap_params
    company = Company.first
    new_company = create_company
    add_new_user(@account, customer_id: new_company.id)
    Helpdesk::Ticket.where(deleted: 0, spam: 0).update_all(requester_id: new_company.users.map(&:id).first)
    get :index, controller_params(company_id: company.id,
                                  requester_id: User.first.id, filter: 'new_and_my_open')
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    user_id = company.users.map(&:id).first
    Helpdesk::Ticket.where(deleted: 0, spam: 0).first.update_attributes(requester_id: user_id,
                                                                        status: 2, responder_id: nil)
    get :index, controller_params(company_id: company.id,
                                  requester_id: user_id, filter: 'new_and_my_open')
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_dates
    get :index, controller_params(updated_since: Time.now.to_s)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    tkt = Helpdesk::Ticket.first
    tkt.update_column(:created_at, 1.days.from_now)
    get :index, controller_params(updated_since: Time.now.to_s)
    assert_response :success
    response = parse_response @response.body
    assert_equal 0, response.size

    tkt.update_column(:updated_at, 1.days.from_now)
    get :index, controller_params(updated_since: Time.now.to_s)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_time_zone
    tkt = Helpdesk::Ticket.where(deleted: false, spam: false).first
    old_time_zone = Time.zone.name
    Time.zone = 'Chennai'
    get :index, controller_params(updated_since: tkt.updated_at.to_s)
    assert_response :success
    response = parse_response @response.body
    assert response.size > 0
    assert response.map { |item| item['ticket_id'] }
    Time.zone = old_time_zone
  end

  def test_show_with_notes_exceeding_limit
    ticket.update_column(:deleted, false)
    (11 - ticket.notes.size).times do
      create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
    end
    get :show, controller_params(id: ticket.display_id, include: 'notes')
    assert_response :success
    match_json(ticket_pattern_with_notes({}, ticket))
    response = parse_response @response.body
    assert_equal 10, response['notes'].size
    assert ticket.reload.notes.size > 10
  end

  def test_show_spam
    t = ticket
    t.update_column(:spam, true)
    get :show, controller_params(id: t.display_id)
    assert_response :success
    match_json(ticket_pattern({}, ticket))
    t.update_column(:spam, false)
  end

  def test_delete_spam
    t = ticket
    t.update_column(:spam, true)
    delete :destroy, controller_params(id: t.display_id)
    assert_response :not_found
    t.update_column(:spam, false)
  end

  def test_update_spam
    t = ticket
    t.update_column(:spam, true)
    put :update, construct_params({ id: t.display_id }, update_ticket_params_hash)
    assert_response :not_found
    t.update_column(:spam, false)
  end

  def test_restore_spam
    t = create_ticket
    t.update_column(:deleted, true)
    t.update_column(:spam, true)
    put :restore, construct_params(id: t.display_id)
    assert_response :not_found
    t.update_column(:spam, false)
  end

  def test_update_array_fields_with_empty_array
    params_hash = update_ticket_params_hash
    t = create_ticket
    put :update, construct_params({ id: t.display_id }, tags: [], cc_emails: [])
    assert_response :success
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_array_fields_with_compacting_array
    tag = Faker::Name.name
    params_hash = update_ticket_params_hash
    t = create_ticket
    put :update, construct_params({ id: t.display_id }, tags: [tag, '', '', nil])
    assert_response :success
    match_json(ticket_pattern({ tags: [tag] }, t.reload))
  end

  def test_index_with_link_header
    3.times do
      create_ticket(requester_id: @agent.id)
    end
    per_page = Helpdesk::Ticket.where(deleted: 0, spam: 0).count - 1
    get :index, controller_params(per_page: per_page)
    assert_response :success
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/tickets?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(per_page: per_page, page: 2)
    assert_response :success
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end
end
