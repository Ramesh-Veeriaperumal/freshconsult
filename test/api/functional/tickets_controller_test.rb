
require_relative '../test_helper'

class TicketsControllerTest < ActionController::TestCase
  include TicketsTestHelper

  CUSTOM_FIELDS = %w(number checkbox decimal text paragraph dropdown country state city date)

  VALIDATABLE_CUSTOM_FIELDS =  %w(number checkbox decimal text paragraph date)

  CUSTOM_FIELDS_VALUES = { 'country' => 'USA', 'state' => 'California', 'city' => 'Burlingame', 'number' => 32_234, 'decimal' => '90.89', 'checkbox' => true, 'text' => Faker::Name.name, 'paragraph' =>  Faker::Lorem.paragraph, 'dropdown' => 'Pursuit of Happiness', 'date' => '2015-09-09' }
  UPDATE_CUSTOM_FIELDS_VALUES = { 'country' => 'Australia', 'state' => 'Queensland', 'city' => 'Brisbane', 'number' => 12, 'decimal' => '8900.89',  'checkbox' => false, 'text' => Faker::Name.name, 'paragraph' =>  Faker::Lorem.paragraph, 'dropdown' => 'Armaggedon', 'date' => '2015-09-09' }
  CUSTOM_FIELDS_VALUES_INVALID = { 'number' => '1.90', 'decimal' => 'dd', 'checkbox' => 'iu', 'text' => Faker::Lorem.characters(300), 'paragraph' =>  12_345, 'date' => '31-13-09' }
  UPDATE_CUSTOM_FIELDS_VALUES_INVALID = { 'number' => '1.89', 'decimal' => 'addsad', 'checkbox' => 'nmbm', 'text' => Faker::Lorem.characters(300), 'paragraph' =>  3_543_534, 'date' => '2015-09-09T09:00' }

  ERROR_PARAMS =  {
    'number' => [:data_type_mismatch, expected_data_type: 'Integer', prepend_msg: :input_received, given_data_type: String],
    'decimal' => [:data_type_mismatch, expected_data_type: 'Number', prepend_msg: :input_received, given_data_type: String],
    'checkbox' => [:data_type_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String],
    'text' => [:"Has 300 characters, it can have maximum of 255 characters"],
    'paragraph' => [:data_type_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer],
    'date' => [:invalid_format, accepted: 'yyyy-mm-dd']
  }

  ERROR_REQUIRED_PARAMS  =  {
    'number' => [:data_type_mismatch, { code: :missing_field, expected_data_type: :Integer }],
    'decimal' => [:data_type_mismatch, { code: :missing_field, expected_data_type: :Number }],
    'checkbox' => [:data_type_mismatch, { code: :missing_field, expected_data_type: :Boolean }],
    'text' => [:data_type_mismatch, { code: :missing_field, expected_data_type: :String }],
    'paragraph' => [:data_type_mismatch, { code: :missing_field, expected_data_type: :String }],
    'date' => [:invalid_format, { code: :missing_field, accepted: 'yyyy-mm-dd' }]
  }
  ERROR_CHOICES_REQUIRED_PARAMS  =  {
    'dropdown' => [:not_included, { code: :missing_field, list: 'Get Smart,Pursuit of Happiness,Armaggedon' }],
    'country' => [:not_included, { code: :missing_field, list: 'Australia,USA' }]
  }

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @@ticket_fields = []
    @@custom_field_names = []
    @@ticket_fields << create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
    @@ticket_fields << create_custom_field_dropdown('test_custom_dropdown', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
    @@choices_custom_field_names = @@ticket_fields.map(&:name)
    CUSTOM_FIELDS.each do |custom_field|
      next if %w(dropdown country state city).include?(custom_field)
      @@ticket_fields << create_custom_field("test_custom_#{custom_field}", custom_field)
      @@custom_field_names << @@ticket_fields.last.name
    end
    @@before_all_run = true
  end

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
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    subject = Faker::Lorem.words(10).join(' ')
    description = Faker::Lorem.paragraph
    @update_group ||= create_group_with_agents(@account, agent_list: [agent.id])
    params_hash = { description: description, subject: subject, priority: 4, status: 3, type: 'Lead',
                    responder_id: agent.id, source: 3, tags: ['update_tag1', 'update_tag2'],
                    due_by: 12.days.since.iso8601, fr_due_by: 4.days.since.iso8601, group_id: @update_group.id }
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
                    due_by: 14.days.since.iso8601, fr_due_by: 1.days.since.iso8601, group_id: @create_group.id }
    params_hash
  end

  def test_create
    params = ticket_params_hash.merge(custom_fields: {})
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({}, params)
    params[:custom_fields]['test_custom_date'] = params[:custom_fields]['test_custom_date'].to_time.iso8601
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    result = parse_response(@response.body)
    assert_equal true, response.headers.include?('Location')
    assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
    assert_response 201
  end

  def test_create_with_email
    params = { email: Faker::Internet.email, status: 2, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    post :create, construct_params({}, params)
    t = Helpdesk::Ticket.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_equal t.requester.email, params[:email]
    assert_response 201
  end

  def test_create_with_email_config_id
    email_config = create_email_config
    params = { requester_id: requester.id, email_config_id: email_config.id, status: 2, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    post :create, construct_params({}, params)
    t = Helpdesk::Ticket.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_equal t.email_config_id, params[:email_config_id]
    assert_response 201
  end

  def test_create_with_invalid_email_config_id
    email_config = EmailConfig.first || create_email_config
    email_config.update_column(:account_id, 999)
    params = { requester_id: requester.id, email_config_id: email_config.reload.id, status: 2, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    post :create, construct_params({}, params)
    email_config.update_column(:account_id, @account.id)
    match_json([bad_request_error_pattern('email_config_id', :invalid_value, resource: :email_config, attribute: :email_config_id)])
    assert_response 400
  end

  def test_update_with_invalid_email_config_id
    email_config = EmailConfig.first || create_email_config
    email_config.update_column(:account_id, 999)
    params = { email_config_id: email_config.reload.id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params)
    email_config.update_column(:account_id, @account.id)
    match_json([bad_request_error_pattern('email_config_id', :invalid_value, resource: :email_config, attribute: :email_config_id)])
    assert_response 400
  end

  def test_create_with_product_id
    product = create_product
    params = { requester_id: requester.id, product_id: product.id, status: 2, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    post :create, construct_params({}, params)
    t = Helpdesk::Ticket.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_equal t.email_config_id, product.primary_email_config.id
    assert_response 201
  end

  def test_create_with_tags_invalid
    params = { requester_id: requester.id, tags: ['test,,,,comma', 'test'], status: 2, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('tags', :special_chars_present, chars: ',')])
    assert_response 400
  end

  def test_create_duplicate_tags
    @account.tags.create(name: 'existing')
    params = { requester_id: requester.id, tags: ['new', '<1>new', 'existing', '<2>existing', 'Existing', 'NEW'],
               status: 2, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    assert_difference 'Helpdesk::Tag.count', 1 do # only new should be inserted.
      assert_difference 'Helpdesk::TagUse.count', 2 do # duplicates should be rejected
        post :create, construct_params({}, params)
      end
    end
    assert_response 201
    params[:tags] = ['new', 'existing']
    t = Helpdesk::Ticket.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
  end

  def test_create_with_responder_id_not_in_group
    group = create_group(@account)
    params = { requester_id: requester.id, responder_id: @agent.id, group_id: group.id, status: 2, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    post :create, construct_params({}, params)
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    assert_response 201
  end

  def test_create_with_product_id_and_email_config_id
    product = create_product
    product_1 = create_product
    email_config = product_1.primary_email_config
    email_config.update_column(:active, true)
    params = { requester_id: requester.id, product_id: product.id, email_config_id: email_config.reload.id, status: 2, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    post :create, construct_params({}, params)
    t = Helpdesk::Ticket.last
    assert_equal t.product_id, product_1.id
    assert_response 201
  end

  def test_create_numericality_invalid
    params = ticket_params_hash.merge(requester_id: 'yu', responder_id: 'io', product_id: 'x', email_config_id: 'x', group_id: 'g')
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('requester_id', :data_type_mismatch, expected_data_type: 'Positive Integer', given_data_type: String, prepend_msg: :input_received),
                bad_request_error_pattern('responder_id', :data_type_mismatch, expected_data_type: 'Positive Integer', given_data_type: String, prepend_msg: :input_received),
                bad_request_error_pattern('product_id', :data_type_mismatch, expected_data_type: 'Positive Integer', given_data_type: String, prepend_msg: :input_received),
                bad_request_error_pattern('email_config_id', :data_type_mismatch, expected_data_type: 'Positive Integer', given_data_type: String, prepend_msg: :input_received),
                bad_request_error_pattern('group_id', :data_type_mismatch, expected_data_type: 'Positive Integer', given_data_type: String, prepend_msg: :input_received)])
    assert_response 400
  end

  def test_create_inclusion_invalid
    params = ticket_params_hash.merge(requester_id: requester.id, priority: 90, status: 56, type: 'jk', source: '89')
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('priority', :not_included, list: '1,2,3,4'),
                bad_request_error_pattern('status', :not_included, list: '2,3,4,5,6,7'),
                bad_request_error_pattern('type', :not_included, list: 'Question,Incident,Problem,Feature Request,Lead'),
                bad_request_error_pattern('source', :not_included, list: '1,2,3,7,8,9')])
    assert_response 400
  end

  def test_create_inclusion_invalid_datatype
    params = ticket_params_hash.merge(requester_id: requester.id, priority: '1', status: '2', source: '9')
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('priority', :not_included, code: :data_type_mismatch, list: '1,2,3,4', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('status', :not_included, code: :data_type_mismatch, list: '2,3,4,5,6,7', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('source', :not_included, code: :data_type_mismatch, list: '1,2,3,7,8,9', prepend_msg: :input_received, given_data_type: String)])
    assert_response 400
  end

  def test_create_length_invalid
    params = ticket_params_hash.except(:email).merge(name: Faker::Lorem.characters(300), subject: Faker::Lorem.characters(300), phone: Faker::Lorem.characters(300), tags: [Faker::Lorem.characters(34)])
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('name', :"Has 300 characters, it can have maximum of 255 characters"),
                bad_request_error_pattern('subject', :"Has 300 characters, it can have maximum of 255 characters"),
                bad_request_error_pattern('phone', :"Has 300 characters, it can have maximum of 255 characters"),
                bad_request_error_pattern('tags', :"Should only contain elements that have maximum of 32 characters")])
    assert_response 400
  end

  def test_create_length_valid_with_trailing_spaces
    trailing_space_params = { custom_fields: { 'test_custom_text' => Faker::Lorem.characters(20) + white_space }, name: Faker::Lorem.characters(20) + white_space, subject: Faker::Lorem.characters(20) + white_space, phone: Faker::Lorem.characters(20) + white_space, tags: [Faker::Lorem.characters(20) + white_space] }
    params = ticket_params_hash.except(:email).merge(trailing_space_params)
    post :create, construct_params({}, params)
    params[:tags].each(&:strip!)
    t = Helpdesk::Ticket.last
    result = params.each { |x, y| y.strip! if [:name, :subject, :phone].include?(x) }
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_equal t.requester.name, result[:name]
    assert_equal t.subject, result[:subject]
    assert_equal t.requester.phone, result[:phone]
    assert_equal t.custom_field["test_custom_text_#{@account.id}"], params[:custom_fields]['test_custom_text'].strip
    assert_response 201
  end

  def test_create_length_invalid_twitter_id
    params = ticket_params_hash.except(:email).merge(twitter_id: Faker::Lorem.characters(300))
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('twitter_id', :"Has 300 characters, it can have maximum of 255 characters")])
    assert_response 400
  end

  def test_create_length_valid_twitter_id_with_trailing_spaces
    params = ticket_params_hash.except(:email).merge(twitter_id: Faker::Lorem.characters(20) + white_space)
    post :create, construct_params({}, params)
    t = Helpdesk::Ticket.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_equal t.requester.twitter_id, params[:twitter_id].strip
    assert_response 201
  end

  def test_create_length_invalid_email
    params = ticket_params_hash.merge(email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(300)}.com")
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('email', :"Has 328 characters, it can have maximum of 255 characters")])
    assert_response 400
  end

  def test_create_length_valid_email_with_trailing_spaces
    params = ticket_params_hash.merge(email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(20)}.com" + white_space)
    post :create, construct_params({}, params)
    t = Helpdesk::Ticket.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_equal t.requester.email, params[:email].strip
    assert_response 201
  end

  def test_create_presence_requester_id_invalid
    params = ticket_params_hash.except(:email)
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('requester_id', :fill_a_mandatory_field, field_names: 'requester_id, phone, email, twitter_id, facebook_id')])
  end

  def test_create_presence_name_invalid
    params = ticket_params_hash.except(:email).merge(phone: Faker::PhoneNumber.phone_number)
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('name', :phone_mandatory)])
  end

  def test_create_email_format_invalid
    params = ticket_params_hash.merge(email: 'test@', cc_emails: ['the@'])
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('email', 'Should be in the valid email address format'),
                bad_request_error_pattern('cc_emails', 'Should contain elements that are in the valid email address format')])
  end

  def test_create_data_type_invalid
    cc_emails = "#{Faker::Internet.email},#{Faker::Internet.email}"
    params = ticket_params_hash.merge(cc_emails: cc_emails, tags: 'tag1,tag2', custom_fields: [1])
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('cc_emails', :data_type_mismatch, expected_data_type: Array, given_data_type: String, prepend_msg: :input_received),
                bad_request_error_pattern('tags', :data_type_mismatch, expected_data_type: Array, given_data_type: String, prepend_msg: :input_received),
                bad_request_error_pattern('custom_fields', :data_type_mismatch, expected_data_type: 'key/value pair', given_data_type: Array, prepend_msg: :input_received)])
    assert_response 400
  end

  def test_create_date_time_invalid
    params = ticket_params_hash.merge(due_by: '7/7669/0', fr_due_by: '7/9889/0')
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('due_by', :invalid_format, accepted: :"combined date and time ISO8601"),
                bad_request_error_pattern('fr_due_by', :invalid_format, accepted: :"combined date and time ISO8601")])
    assert_response 400
  end

  def test_create_with_nil_due_by_without_fr_due_by
    params = ticket_params_hash.except(:fr_due_by).merge(status: 5, due_by: nil)
    post :create, construct_params({}, params)
    t = Helpdesk::Ticket.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    t.update_column(:status, 2)
    assert_not_nil t.due_by && t.frDueBy
    assert_response 201
  end

  def test_create_with_nil_fr_due_by_without_due_by
    params = ticket_params_hash.except(:due_by).merge(status: 5, fr_due_by: nil)
    post :create, construct_params({}, params)
    t = Helpdesk::Ticket.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    t.update_column(:status, 2)
    assert_not_nil t.due_by && t.frDueBy
    assert_response 201
  end

  def test_create_closed_with_nil_fr_due_by_with_due_by
    time = 12.days.since.iso8601
    params = ticket_params_hash.merge(status: 5, fr_due_by: nil, due_by: time)
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :cannot_set_due_by_fields, code: :incompatible_field)])
  end

  def test_create_with_nil_fr_due_by_with_due_by
    params = ticket_params_hash.merge(fr_due_by: nil, due_by: 12.days.since.iso8601)
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('fr_due_by', :fr_due_by_validation)])
  end

  def test_create_with_nil_due_by_with_fr_due_by
    params = ticket_params_hash.merge(due_by: nil, fr_due_by: 12.days.since.iso8601)
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :due_by_validation)])
  end

  def test_create_closed_with_nil_due_by_fr_due_by
    params = ticket_params_hash.merge(status: 5, due_by: nil, fr_due_by: nil)
    post :create, construct_params({}, params)
    t = Helpdesk::Ticket.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    t.update_column(:status, 2)
    assert_not_nil t.due_by && t.frDueBy
    assert_response 201
  end

  def test_create_with_nil_due_by_fr_due_by
    params = ticket_params_hash.merge(due_by: nil, fr_due_by: nil)
    post :create, construct_params({}, params)
    t = Helpdesk::Ticket.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_not_nil t.due_by && t.frDueBy
    assert_response 201
  end

  def test_create_with_due_by_without_fr_due_by
    params = ticket_params_hash.except(:due_by, :fr_due_by).merge(due_by: 12.days.since.iso8601)
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('fr_due_by', :fr_due_by_validation)])
  end

  def test_create_without_due_by_with_fr_due_by
    params = ticket_params_hash.except(:due_by, :fr_due_by).merge(fr_due_by: 12.days.since.iso8601)
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :due_by_validation)])
  end

  def test_create_with_due_by_and_fr_due_by
    params = ticket_params_hash
    Helpdesk::Ticket.any_instance.expects(:update_dueby).never
    post :create, construct_params({}, params)
    assert_response 201
  end

  def test_create_without_due_by_and_fr_due_by
    params = ticket_params_hash.except(:fr_due_by, :due_by)
    Helpdesk::Ticket.any_instance.expects(:update_dueby).once
    post :create, construct_params({}, params)
    assert_response 201
  end

  def test_create_with_invalid_fr_due_by_and_due_by
    params = ticket_params_hash.merge(fr_due_by: 30.days.ago.iso8601, due_by: 30.days.ago.iso8601)
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :gt_created_and_now),
                bad_request_error_pattern('fr_due_by', :gt_created_and_now)])
  end

  def test_create_with_invalid_due_by_and_cc_emails_count
    cc_emails = []
    50.times do
      cc_emails << Faker::Internet.email
    end
    params = ticket_params_hash.merge(due_by: 30.days.ago.iso8601, cc_emails: cc_emails)
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('cc_emails', :too_long, entities: :values, max_count: "#{ApiTicketConstants::MAX_EMAIL_COUNT}", current_count: 50),
                bad_request_error_pattern('due_by', :gt_created_and_now)])
  end

  def test_create_with_due_by_greater_than_created_at_less_than_fr_due_by
    due_by = 30.days.since.utc.iso8601
    fr_due_by = 31.days.since.utc.iso8601
    params = ticket_params_hash.merge(due_by: due_by, fr_due_by: fr_due_by)
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('fr_due_by', 'lt_due_by')])
    assert_response 400
  end

  def test_create_invalid_model
    user = add_new_user(@account)
    user.update_attribute(:blocked, true)
    cc_emails = []
    51.times do
      cc_emails << Faker::Internet.email
    end
    params = ticket_params_hash.except(:email).merge(custom_fields: { 'test_custom_country' => 'rtt', 'test_custom_dropdown' => 'ddd' }, group_id: 89_089, product_id: 9090, email_config_id: 89_789, responder_id: 8987, requester_id: user.id)
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('group_id', :invalid_value, resource: :group, attribute: :group_id),
                bad_request_error_pattern('responder_id', :invalid_value, resource: :agent, attribute: :responder_id),
                bad_request_error_pattern('email_config_id', :invalid_value, resource: :email_config, attribute: :email_config_id),
                bad_request_error_pattern('product_id', :invalid_value, resource: :product, attribute: :product_id),
                bad_request_error_pattern('requester_id', :user_blocked),
                bad_request_error_pattern('test_custom_country', :not_included, list: 'Australia,USA'),
                bad_request_error_pattern('test_custom_dropdown', :not_included, list:  'Get Smart,Pursuit of Happiness,Armaggedon')])
  end

  def test_create_with_default_product_assignment_from_portal
    portal = @account.main_portal
    product = Product.first || create_product
    portal.update_column(:product_id, product.id)
    post :create, construct_params({}, ticket_params_hash)
    assert_response 201
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    assert_equal product.id, Helpdesk::Ticket.last.product_id
    portal.update_column(:product_id, nil)
  end

  def test_create_invalid_user_id
    params = ticket_params_hash.except(:email).merge(requester_id: 898_999)
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('requester_id', :invalid_value, attribute: :requester_id, resource: :contact)])
  end

  def test_create_extra_params_invalid
    params = ticket_params_hash.merge(junk: 'test')
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('junk', :invalid_field)])
  end

  def test_create_empty_params
    params = {}
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('requester_id', :fill_a_mandatory_field, field_names: 'requester_id, phone, email, twitter_id, facebook_id'),
                bad_request_error_pattern('subject', :data_type_mismatch, expected_data_type: String),
                bad_request_error_pattern('description', :data_type_mismatch, expected_data_type: String),
                bad_request_error_pattern('priority', :not_included, code: :missing_field, list: '1,2,3,4'),
                bad_request_error_pattern('status', :not_included, code: :missing_field, list: '2,3,4,5,6,7')])
  end

  def test_create_datatype_invalid
    post :create, construct_params({}, ticket_params_hash.merge(description: true, description_html: true))
    assert_response 400
    match_json([bad_request_error_pattern('description', :data_type_mismatch, expected_data_type: String, given_data_type: 'Boolean', prepend_msg: :input_received),
                bad_request_error_pattern('description_html', :data_type_mismatch, expected_data_type: String, given_data_type: 'Boolean', prepend_msg: :input_received)])
  end

  def test_create_with_existing_user
    params = ticket_params_hash.except(:email).merge(requester_id: requester.id)
    post :create, construct_params({}, params)
    assert_response 201
    assert_equal Helpdesk::Ticket.last.requester_id, params[:requester_id]
  end

  def test_create_with_new_twitter_user
    params = ticket_params_hash.except(:email).merge(twitter_id: '@test')
    post :create, construct_params({}, params)
    assert_response 201
    assert_equal Helpdesk::Ticket.last.requester.twitter_id, params[:twitter_id]
    assert User.last.twitter_id == '@test'
  end

  def test_create_with_new_phone_user
    phone = Faker::PhoneNumber.phone_number
    params = ticket_params_hash.except(:email).merge(phone: phone, name: Faker::Name.name)
    post :create, construct_params({}, params)
    assert_response 201
    assert_equal Helpdesk::Ticket.last.requester.phone, params[:phone]
    assert User.last.phone == phone
    assert User.last.name == params[:name]
  end

  def test_create_with_new_fb_user
    params = ticket_params_hash.except(:email).merge(facebook_id:  Faker::Name.name)
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('facebook_id', :invalid_facebook_id)])
  end

  def test_create_with_existing_fb_user
    user = add_new_user_with_fb_id(@account)
    count = User.count
    params = ticket_params_hash.except(:email).merge(facebook_id: user.fb_profile_id)
    post :create, construct_params({}, params)
    assert_response 201
    assert_equal Helpdesk::Ticket.last.requester.fb_profile_id, params[:facebook_id]
    assert User.count == count
  end

  def test_create_with_existing_twitter
    user = add_new_user_with_twitter_id(@account)
    count = User.count
    params = ticket_params_hash.except(:email).merge(twitter_id: user.twitter_id)
    post :create, construct_params({}, params)
    assert_response 201
    assert_equal Helpdesk::Ticket.last.requester.twitter_id, params[:twitter_id]
    assert User.count == count
  end

  def test_create_with_existing_phone
    user = add_new_user_without_email(@account)
    count = User.count
    params = ticket_params_hash.except(:email).merge(phone: user.phone, name: Faker::Name.name)
    post :create, construct_params({}, params)
    assert_response 201
    assert_equal Helpdesk::Ticket.last.requester.phone, params[:phone]
    assert User.count == count
  end

  def test_create_with_existing_email
    user = add_new_user(@account)
    count = User.count
    params = ticket_params_hash.except(:email).merge(email: user.email)
    post :create, construct_params({}, params)
    assert_response 201
    assert_equal Helpdesk::Ticket.last.requester.email, params[:email]
    assert User.count == count
  end

  def test_create_with_invalid_custom_fields
    params = ticket_params_hash.merge('custom_fields' => { 'dsfsdf' => 'dsfsdf' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('dsfsdf', :invalid_field)])
  end

  def test_create_with_attachment
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = ticket_params_hash.merge('attachments' => [file, file2], status: '2', priority: '2', source: '2')
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    post :create, construct_params({}, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    response_params = params.except(:tags, :attachments)
    match_json(ticket_pattern(params.merge(status: 2, priority: 2, source: 2), Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    assert_response 201
    assert Helpdesk::Ticket.last.attachments.count == 2
  end

  def test_create_with_invalid_attachment_array
    params = ticket_params_hash.merge('attachments' => [1, 2])
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_data_type_mismatch, expected_data_type: 'valid file format')])
  end

  def test_create_with_invalid_attachment_type
    params = ticket_params_hash.merge('attachments' => 'test')
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :data_type_mismatch, expected_data_type: Array, given_data_type: String, prepend_msg: :input_received)])
  end

  def test_create_with_invalid_empty_attachment
    params = ticket_params_hash.merge('attachments' => [])
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :blank)])
  end

  def test_attachment_invalid_size_create
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(20_000_000)
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    params = ticket_params_hash.merge('attachments' => [file])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({}, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: '15 MB', current_size: '19.1 MB')])
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
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: '15 MB', current_size: '19.1 MB')])
  end

  def test_create_with_nested_custom_fields_with_invalid_first_children_valid
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'uyiyiuy', 'test_custom_state' => 'Queensland', 'test_custom_city' => 'Brisbane' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_country', :not_included, list: 'Australia,USA')])
  end

  def test_create_with_nested_custom_fields_with_invalid_first_children_invalid
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'uyiyiuy', 'test_custom_state' => 'ss', 'test_custom_city' => 'ss' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_country', :not_included, list: 'Australia,USA')])
  end

  def test_create_with_nested_custom_fields_with_valid_first_invalid_second_valid_third
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'hjhj', 'test_custom_city' => 'Brisbane' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_state', :not_included, list: 'New South Wales,Queensland')])
  end

  def test_create_with_nested_custom_fields_with_valid_first_invalid_second_without_third
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'hjhj' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_state', :not_included, list: 'New South Wales,Queensland')])
  end

  def test_create_with_nested_custom_fields_with_valid_first_invalid_second_without_third_invalid_third
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'hjhj', 'test_custom_city' => 'sfs' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_state', :not_included, list: 'New South Wales,Queensland')])
  end

  def test_create_with_nested_custom_fields_with_valid_first_valid_second_invalid_third
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'Queensland', 'test_custom_city' => 'ddd' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_city', :not_included, list: 'Brisbane')])
  end

  def test_create_with_nested_custom_fields_with_valid_first_valid_second_invalid_other_third
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'Queensland', 'test_custom_city' => 'Sydney' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_city', :not_included, list: 'Brisbane')])
  end

  def test_create_with_nested_custom_fields_without_first_with_second_and_third
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_state' => 'Queensland', 'test_custom_city' => 'Brisbane' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_country', :conditional_not_blank, child: 'test_custom_state')])
  end

  def test_create_with_nested_custom_fields_without_first_with_second_only
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_state' => 'Queensland' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_country', :conditional_not_blank, child: 'test_custom_state')])
  end

  def test_create_with_nested_custom_fields_without_first_with_third_only
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_city' => 'Brisbane' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_country', :conditional_not_blank, child: 'test_custom_city'),
                bad_request_error_pattern('test_custom_state', :conditional_not_blank, child: 'test_custom_city')])
  end

  def test_create_with_nested_custom_fields_without_second_with_third
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_city' => 'Brisbane' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_state', :conditional_not_blank, child: 'test_custom_city')])
  end

  def test_create_with_nested_custom_fields_required_without_second_level
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia' })
    ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
    ticket_field.update_attribute(:required, true)
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required, false)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_state', :not_included, code: :missing_field, list: 'New South Wales,Queensland')])
  end

  def test_create_with_nested_custom_fields_required_without_third_level
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'Queensland' })
    ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
    ticket_field.update_attribute(:required, true)
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required, false)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_city', :not_included, code: :missing_field, list: 'Brisbane')])
  end

  def test_create_with_nested_custom_fields_required_for_closure_without_second_level
    params = ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4, custom_fields: { 'test_custom_country' => 'Australia' })
    ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
    ticket_field.update_attribute(:required_for_closure, true)
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_state', :not_included, code: :missing_field, list: 'New South Wales,Queensland')])
  end

  def test_create_with_nested_custom_fields_required_for_closure_without_third_level
    params = ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4, custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'Queensland' })
    ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
    ticket_field.update_attribute(:required_for_closure, true)
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_city', :not_included, code: :missing_field, list: 'Brisbane')])
  end

  def test_create_notify_cc_emails
    params = ticket_params_hash
    controller.class.any_instance.expects(:notify_cc_people).once
    post :create, construct_params({}, params)
    assert_response 201
  end

  def test_create_with_custom_fields_required_for_closure_with_status_closed
    params = ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 5)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required_for_closure: true)
    post :create, construct_params({}, params)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required_for_closure: false)
    assert_response 400
    pattern = []
    (VALIDATABLE_CUSTOM_FIELDS).each do |custom_field|
      pattern << bad_request_error_pattern("test_custom_#{custom_field}", *(ERROR_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
  end

  def test_create_with_custom_fields_required_for_closure_with_status_resolved
    params = ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required_for_closure: true)
    post :create, construct_params({}, params)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required_for_closure: false)
    assert_response 400
    pattern = []
    (VALIDATABLE_CUSTOM_FIELDS).each do |custom_field|
      pattern << bad_request_error_pattern("test_custom_#{custom_field}", *(ERROR_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
  end

  def test_create_with_custom_fields_required
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
    post :create, construct_params({}, params)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
    assert_response 400
    pattern = []
    (VALIDATABLE_CUSTOM_FIELDS).each do |custom_field|
      pattern << bad_request_error_pattern("test_custom_#{custom_field}", *(ERROR_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
  end

  def test_create_with_choices_custom_fields_required_for_closure_with_status_closed
    params = ticket_params_hash.merge(custom_fields: {})
    params = params.except(:fr_due_by, :due_by).merge(status: 5)
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required_for_closure: true)
    post :create, construct_params({}, params)
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required_for_closure: false)
    assert_response 400
    pattern = []
    ['dropdown', 'country'].each do |custom_field|
      pattern << bad_request_error_pattern("test_custom_#{custom_field}", *(ERROR_CHOICES_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
  end

  def test_create_with_choices_custom_fields_required_for_closure_with_status_resolved
    params = ticket_params_hash.merge(custom_fields: {})
    params = params.except(:fr_due_by, :due_by).merge(status: 4)
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required_for_closure: true)
    post :create, construct_params({}, params)
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required_for_closure: false)
    assert_response 400
    pattern = []
    ['dropdown', 'country'].each do |custom_field|
      pattern << bad_request_error_pattern("test_custom_#{custom_field}", *(ERROR_CHOICES_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
  end

  def test_create_with_choices_custom_fields_required
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required: true)
    post :create, construct_params({}, params)
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required: false)
    assert_response 400
    pattern = []
    ['dropdown', 'country'].each do |custom_field|
      pattern << bad_request_error_pattern("test_custom_#{custom_field}", *(ERROR_CHOICES_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
  end

  def test_create_with_custom_fields_invalid
    params = ticket_params_hash.merge(custom_fields: {})
    VALIDATABLE_CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES_INVALID[custom_field]
    end
    post :create, construct_params({}, params)
    assert_response 400
    pattern = []
    VALIDATABLE_CUSTOM_FIELDS.each do |custom_field|
      pattern << bad_request_error_pattern("test_custom_#{custom_field}", *(ERROR_PARAMS[custom_field]))
    end
    match_json(pattern)
  end

  def test_update_with_custom_fields_invalid
    params_hash = update_ticket_params_hash.merge(custom_fields: {})
    VALIDATABLE_CUSTOM_FIELDS.each do |custom_field|
      params_hash[:custom_fields]["test_custom_#{custom_field}"] = UPDATE_CUSTOM_FIELDS_VALUES_INVALID[custom_field]
    end
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    pattern = []
    VALIDATABLE_CUSTOM_FIELDS.each do |custom_field|
      pattern << bad_request_error_pattern("test_custom_#{custom_field}",  *(ERROR_PARAMS[custom_field]))
    end
    match_json(pattern)
  end

  def test_update_with_custom_fields_required_for_closure_with_status_closed
    t = ticket
    params_hash = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 5)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required_for_closure: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required_for_closure: false)
    pattern = []
    (VALIDATABLE_CUSTOM_FIELDS).each do |custom_field|
      pattern << bad_request_error_pattern("test_custom_#{custom_field}", *(ERROR_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
    assert_response 400
  end

  def test_update_with_custom_fields_required_for_closure_with_status_resolved
    t = ticket
    params_hash = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required_for_closure: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required_for_closure: false)
    pattern = []
    (VALIDATABLE_CUSTOM_FIELDS).each do |custom_field|
      pattern << bad_request_error_pattern("test_custom_#{custom_field}", *(ERROR_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
    assert_response 400
  end

  def test_update_with_custom_fields_required
    params_hash = update_ticket_params_hash
    t = ticket
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
    assert_response 400
    pattern = []
    (VALIDATABLE_CUSTOM_FIELDS).each do |custom_field|
      pattern << bad_request_error_pattern("test_custom_#{custom_field}", *(ERROR_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
  end

  def test_update_with_choices_custom_fields_required_for_closure_with_status_closed
    t = ticket
    params_hash = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 5)
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required_for_closure: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required_for_closure: false)
    pattern = []
    ['dropdown', 'country'].each do |custom_field|
      pattern << bad_request_error_pattern("test_custom_#{custom_field}", *(ERROR_CHOICES_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
    assert_response 400
  end

  def test_update_with_choices_custom_fields_required_for_closure_with_status_resolved
    t = ticket
    params_hash = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4)
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required_for_closure: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required_for_closure: false)
    pattern = []
    ['dropdown', 'country'].each do |custom_field|
      pattern << bad_request_error_pattern("test_custom_#{custom_field}", *(ERROR_CHOICES_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
    assert_response 400
  end

  def test_update_with_choices_custom_fields_required
    params_hash = update_ticket_params_hash
    t = ticket
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required: false)
    assert_response 400
    pattern = []
    ['dropdown', 'country'].each do |custom_field|
      pattern << bad_request_error_pattern("test_custom_#{custom_field}", *(ERROR_CHOICES_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
  end

  def test_update_with_attachment
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = update_ticket_params_hash.merge('attachments' => [file, file2])
    t = ticket
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    put :update, construct_params({ id: t.display_id }, params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    response_params = params.except(:tags, :attachments)
    match_json(ticket_pattern(params, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    assert ticket.attachments.count == 2
  end

  def test_update_with_invalid_attachment_params_format
    params = update_ticket_params_hash.merge('attachments' => [1, 2])
    put :update, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_data_type_mismatch, expected_data_type: 'valid file format')])
  end

  def test_update
    portal = @account.main_portal
    product = Product.first || create_product
    portal.update_column(:product_id, product.id)
    params_hash = update_ticket_params_hash.merge(custom_fields: {})
    CUSTOM_FIELDS.each do |custom_field|
      params_hash[:custom_fields]["test_custom_#{custom_field}"] = UPDATE_CUSTOM_FIELDS_VALUES[custom_field]
    end
    t = ticket
    t.schema_less_ticket.update_column(:product_id, nil)
    put :update, construct_params({ id: t.display_id }, params_hash)
    params_hash[:custom_fields]['test_custom_date'] = params_hash[:custom_fields]['test_custom_date'].to_time.iso8601
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t.reload))
    assert_response 200
    assert_nil t.product_id
    portal.update_column(:product_id, nil)
  end

  def test_update_closed_with_nil_due_by_without_fr_due_by
    t = ticket
    params = update_ticket_params_hash.except(:fr_due_by).merge(status: 5, due_by: nil)
    put :update, construct_params({ id: t.display_id }, params)
    t = Helpdesk::Ticket.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 200
    t.update_column(:status, 2)
    assert_not_nil t.due_by && t.frDueBy
  end

  def test_update_with_nil_fr_due_by_without_due_by
    t = ticket
    params = update_ticket_params_hash.except(:due_by).merge(status: 5, fr_due_by: nil)
    put :update, construct_params({ id: t.display_id }, params)
    t = Helpdesk::Ticket.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 200
    t.update_column(:status, 2)
    assert_not_nil t.due_by && t.frDueBy
  end

  def test_update_closed_with_nil_fr_due_by_with_due_by
    t = ticket
    time = 12.days.since.iso8601
    params = update_ticket_params_hash.merge(status: 5, fr_due_by: nil, due_by: time)
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :cannot_set_due_by_fields, code: :incompatible_field)])
  end

  def test_update_with_nil_fr_due_by_with_due_by
    t = ticket
    fr_due_by = Time.zone.now
    t.update_column(:frDueBy, fr_due_by)
    t.update_attribute(:manual_dueby, true)
    due_by = 12.days.since.utc.iso8601
    params = update_ticket_params_hash.merge(fr_due_by: nil, due_by: due_by)
    put :update, construct_params({ id: t.display_id }, params)
    match_json(ticket_pattern(params, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    assert_equal fr_due_by.utc.iso8601, t.reload.frDueBy.iso8601
    assert_equal due_by, t.due_by.iso8601
  end

  def test_update_with_nil_due_by_with_fr_due_by
    t = ticket
    fr_due_by = 2.days.since.utc.iso8601
    params = update_ticket_params_hash.merge(due_by: nil, fr_due_by: fr_due_by)
    put :update, construct_params({ id: t.display_id }, params)
    match_json(ticket_pattern(params, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    t.update_column(:status, 2)
    assert_not_nil t.reload.due_by
    assert_equal fr_due_by, t.frDueBy.iso8601
  end

  def test_update_closed_with_nil_due_by_fr_due_by
    t = ticket
    params = update_ticket_params_hash.merge(status: 5, due_by: nil, fr_due_by: nil)
    put :update, construct_params({ id: t.display_id }, params)
    match_json(ticket_pattern(params, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    t.update_column(:status, 2)
    assert_not_nil t.due_by && t.frDueBy
  end

  def test_update_with_nil_due_by_fr_due_by
    t = ticket
    params = update_ticket_params_hash.merge(due_by: nil, fr_due_by: nil)
    put :update, construct_params({ id: t.display_id }, params)
    match_json(ticket_pattern(params, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    assert_not_nil t.due_by && t.frDueBy
  end

  def test_update_with_invalid_fr_due_by
    params = update_ticket_params_hash.merge(fr_due_by: 30.days.ago.iso8601)
    t = ticket
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('fr_due_by', :gt_created_and_now)])
  end

  def test_update_with_invalid_fr_due_by_and_due_by
    params = update_ticket_params_hash.merge(fr_due_by: 30.days.ago.iso8601, due_by: 30.days.ago.iso8601)
    t = ticket
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :gt_created_and_now),
                bad_request_error_pattern('fr_due_by', :gt_created_and_now)])
  end

  def test_update_with_invalid_due_by
    params = update_ticket_params_hash.merge(due_by: 30.days.ago.iso8601)
    t = ticket
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :gt_created_and_now)])
  end

  def test_update_with_due_by_greater_than_created_at_less_than_fr_due_by
    # both in params
    t = ticket
    due_by = 30.days.since.utc.iso8601
    fr_due_by = 31.days.since.utc.iso8601
    params = update_ticket_params_hash.merge(due_by: due_by, fr_due_by: fr_due_by)
    put :update, construct_params({ id: t.id }, params)
    match_json([bad_request_error_pattern('fr_due_by', 'lt_due_by')])
    assert_response 400

    # fr_due_by in params
    t = ticket
    due_by = 30.days.since.utc.iso8601
    t.update_column(:due_by, due_by)
    fr_due_by = 31.days.since.utc.iso8601
    params = update_ticket_params_hash.except(:due_by).merge(fr_due_by: fr_due_by)
    put :update, construct_params({ id: t.id }, params)
    match_json([bad_request_error_pattern('fr_due_by', 'lt_due_by')])
    assert_response 400

    # due_by in params
    t = ticket
    due_by = 30.days.since.utc.iso8601
    fr_due_by = 31.days.since.utc.iso8601
    t.update_column(:frDueBy, fr_due_by)
    params = update_ticket_params_hash.except(:fr_due_by).merge(due_by: due_by)
    put :update, construct_params({ id: t.id }, params)
    match_json([bad_request_error_pattern('due_by', 'lt_due_by')])
    assert_response 400
  end

  def test_update_without_due_by
    params = update_ticket_params_hash
    t = ticket
    t.update_attribute(:due_by, (t.created_at - 10.days).iso8601)
    put :update, construct_params({ id: t.display_id }, params)
    match_json(ticket_pattern(params, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
  end

  def test_update_without_fr_due_by
    params = update_ticket_params_hash
    t = ticket
    t.update_attribute(:frDueBy, (t.created_at - 10.days).iso8601)
    put :update, construct_params({ id: t.display_id }, params)
    match_json(ticket_pattern(params, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
  end

  def test_update_invalid_model
    user = add_new_user(@account)
    user.update_attribute(:blocked, true)
    params = update_ticket_params_hash.except(:email).merge(custom_fields: { 'test_custom_country' => 'rtt', 'test_custom_dropdown' => 'ddd' }, group_id: 89_089, product_id: 9090, email_config_id: 89_789, responder_id: 8987, requester_id: user.id)
    t = ticket
    t.update_column(:requester_id, nil)
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('group_id', :invalid_value, resource: :group, attribute: :group_id),
                bad_request_error_pattern('responder_id', :invalid_value, resource: :agent, attribute: :responder_id),
                bad_request_error_pattern('email_config_id', :invalid_value, resource: :email_config, attribute: :email_config_id),
                bad_request_error_pattern('requester_id', :user_blocked),
                bad_request_error_pattern('product_id', :invalid_value, resource: :product, attribute: :product_id),
                bad_request_error_pattern('test_custom_country', :not_included, list: 'Australia,USA'),
                bad_request_error_pattern('test_custom_dropdown', :not_included, list:  'Get Smart,Pursuit of Happiness,Armaggedon')])
  end

  def test_update_inconsistency_already_in_model
    user = add_new_user(@account)
    user.update_attribute(:blocked, true)
    params = { requester_id: user.id, email_config_id: 8888, responder_id: 8888, group_id: 8888 }
    t = ticket
    Helpdesk::Ticket.update_all(params, id: t.id)
    t.schema_less_ticket.update_column(:product_id, 8888)
    t.schema_less_ticket.reload
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 200
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_responder_id_not_in_group
    group = create_group(@account)
    params = { responder_id: @agent.id, group_id: group.id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params)
    match_json(ticket_pattern(params, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
  end

  def test_update_with_email_config_id
    email_config = create_email_config
    params_hash = { email_config_id: email_config.id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_equal t.reload.email_config_id, params_hash[:email_config_id]
    match_json(ticket_pattern({}, t))
    assert_response 200
  end

  def test_update_with_product_id
    product = create_product
    params_hash = { product_id: product.id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_equal t.reload.email_config_id, product.primary_email_config.id
    match_json(ticket_pattern({}, t))
    assert_response 200
  end

  def test_update_with_product_id_and_diff_email_config_id
    product = create_product
    product_1 = create_product
    email_config = product_1.primary_email_config
    email_config.update_column(:active, true)
    params_hash = { product_id: product.id, email_config_id: email_config.reload.id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 200
    assert_equal t.reload.email_config_id, product.primary_email_config.id
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_with_product_id_and_same_email_config_id
    product = create_product
    email_config = create_email_config(product_id: product.id)
    params_hash = { product_id: product.id, email_config_id: email_config.id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_equal t.reload.email_config_id, params_hash[:email_config_id]
    assert_equal t.product_id, params_hash[:product_id]
    match_json(ticket_pattern({}, t))
    assert_response 200
  end

  def test_update_with_low_priority
    params_hash = { priority: 1 }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert t.reload.priority == 1
    match_json(ticket_pattern({}, t.reload))
    assert_response 200
  end

  def test_update_with_type
    params_hash = { type: 'Incident' }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(ticket_pattern({}, t.reload))
    assert_response 200
    assert t.reload.ticket_type == 'Incident'
  end

  def test_update_with_tags_invalid
    t = ticket
    params_hash = { tags: ['test,,,,comma', 'test'] }
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('tags', :special_chars_present, chars: ',')])
  end

  def test_update_with_subject
    subject = Faker::Lorem.words(10).join(' ')
    params_hash = { subject: subject }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert t.reload.subject == subject
    match_json(ticket_pattern({}, t.reload))
    assert_response 200
  end

  def test_update_with_description
    description =  Faker::Lorem.paragraph
    params_hash = { description: description }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert t.reload.description == description
    match_json(ticket_pattern({}, t.reload))
    assert_response 200
  end

  def test_update_with_responder_id_in_group
    responder_id = add_test_agent(@account).id
    params_hash = { responder_id: responder_id }
    t = ticket
    group = t.group
    group.agent_groups.create(user_id: responder_id, group_id: group.id)
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(ticket_pattern({}, t.reload))
    assert_response 200
    assert t.reload.responder_id == responder_id
  end

  def test_update_with_requester_id
    requester_id = add_new_user(@account).id
    params_hash = { requester_id: requester_id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert t.reload.requester_id == requester_id
    match_json(ticket_pattern({}, t.reload))
    assert_response 200
  end

  def test_update_with_group_id
    t = ticket
    group_id = create_group_with_agents(@account, agent_list: [t.responder_id]).id
    params_hash = { group_id: group_id }
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert t.reload.group_id == group_id
    match_json(ticket_pattern({}, t.reload))
    assert_response 200
  end

  def test_update_with_source
    params_hash = { source: 2 }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(ticket_pattern({}, t.reload))
    assert_response 200
    assert t.reload.source == 2
  end

  def test_update_with_tags
    tags = [Faker::Name.name, Faker::Name.name]
    params_hash = { tags: tags }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert t.reload.tag_names == tags
    match_json(ticket_pattern({}, t.reload))
    assert_response 200
  end

  def test_update_with_closed_status
    params_hash = { status: 5 }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert t.reload.status == 5
    match_json(ticket_pattern({}, t.reload))
    assert_response 200
  end

  def test_update_with_resolved_status
    params_hash = { status: 4 }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(ticket_pattern({}, t.reload))
    assert_response 200
    assert t.reload.status == 4
  end

  def test_update_with_new_email_without_nil_requester_id
    params_hash = update_ticket_params_hash.merge(email:  Faker::Internet.email)
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 200
    assert User.count == count + 1
  end

  def test_update_with_new_twitter_id_without_nil_requester_id
    params_hash = update_ticket_params_hash.merge(twitter_id:  "@#{Faker::Name.name}")
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 200
    assert User.count == count + 1
  end

  def test_update_with_new_phone_without_nil_requester_id
    params_hash = update_ticket_params_hash.merge(phone: Faker::PhoneNumber.phone_number, name:  Faker::Name.name)
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 200
    assert User.count == count + 1
  end

  def test_update_with_new_email_with_nil_requester_id
    email = Faker::Internet.email
    params_hash = update_ticket_params_hash.merge(email: email, requester_id: nil)
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    assert User.count == (count + 1)
    assert User.find(t.requester_id).email == email
  end

  def test_update_with_new_twitter_id_with_nil_requester_id
    twitter_id = "@#{Faker::Name.name}"
    params_hash = update_ticket_params_hash.merge(twitter_id: twitter_id, requester_id: nil)
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
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
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    assert User.count == (count + 1)
    assert User.find(t.reload.requester_id).phone == phone
    assert User.find(t.reload.requester_id).name == name
  end

  def test_update_with_due_by_and_fr_due_by
    t = ticket
    previous_fr_due_by = t.frDueBy
    previous_due_by = t.due_by
    params_hash = { fr_due_by: 2.hours.since.iso8601, due_by: 100.days.since.iso8601 }
    Helpdesk::Ticket.any_instance.expects(:update_dueby).never
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    assert t.reload.due_by == params_hash[:due_by]
    assert t.reload.frDueBy == params_hash[:fr_due_by]
  end

  def test_update_with_due_by
    t = create_ticket(ticket_params_hash.except(:fr_due_by, :due_by))
    previous_due_by = t.due_by
    params_hash = { due_by: 100.days.since.iso8601 }
    Helpdesk::Ticket.any_instance.expects(:update_dueby).never
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    assert t.reload.due_by != previous_due_by
  end

  def test_update_with_fr_due_by
    t = create_ticket(ticket_params_hash.except(:fr_due_by, :due_by))
    previous_fr_due_by = t.frDueBy
    params_hash = { fr_due_by: 2.hours.since.iso8601 }
    Helpdesk::Ticket.any_instance.expects(:update_dueby).never
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    assert t.reload.frDueBy != previous_fr_due_by
  end

  def test_update_with_new_fb_id
    t = ticket
    params_hash = update_ticket_params_hash.merge(facebook_id: Faker::Name.name)
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('facebook_id', :invalid_facebook_id)])
  end

  def test_update_with_status_resolved_and_due_by
    t = ticket
    time1 = 12.days.since.iso8601
    time2 = 4.days.since.iso8601
    params_hash = { status: 4, due_by: time1, fr_due_by: time2 }
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :cannot_set_due_by_fields, code: :incompatible_field),
                bad_request_error_pattern('fr_due_by', :cannot_set_due_by_fields, code: :incompatible_field)])
  end

  def test_update_with_status_resolved_and_only_due_by
    t = ticket
    time = 12.days.since.iso8601
    params_hash = { status: 4, due_by: time }
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :cannot_set_due_by_fields, code: :incompatible_field)])
  end

  def test_update_with_status_closed_and_only_fr_due_by
    t = ticket
    time = 4.days.since.iso8601
    params_hash = { status: 5, fr_due_by: time }
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('fr_due_by', :cannot_set_due_by_fields, code: :incompatible_field)])
  end

  def test_update_with_status_closed_and_due_by
    t = ticket
    time1 = 12.days.since.iso8601
    time2 = 4.days.since.iso8601
    params_hash = { status: 5, due_by: time1, fr_due_by: time2 }
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :cannot_set_due_by_fields, code: :incompatible_field),
                bad_request_error_pattern('fr_due_by', :cannot_set_due_by_fields, code: :incompatible_field)])
  end

  def test_update_numericality_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: 'yu', responder_id: 'io', product_id: 'x', email_config_id: 'x', group_id: 'g')
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('requester_id', :data_type_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('responder_id', :data_type_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('product_id', :data_type_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('email_config_id', :data_type_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('group_id', :data_type_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)])
  end

  def test_update_inclusion_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: requester.id, priority: 90, status: 56, type: 'jk', source: '89')
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('priority', :not_included, list: '1,2,3,4'),
                bad_request_error_pattern('status', :not_included, list: '2,3,4,5,6,7'),
                bad_request_error_pattern('type', :not_included, list: 'Question,Incident,Problem,Feature Request,Lead'),
                bad_request_error_pattern('source', :not_included, list: '1,2,3,7,8,9')])
  end

  def test_update_length_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(name: Faker::Lorem.characters(300), requester_id: nil, subject: Faker::Lorem.characters(300), phone: Faker::Lorem.characters(300), tags: [Faker::Lorem.characters(34)])
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json([bad_request_error_pattern('name', :"Has 300 characters, it can have maximum of 255 characters"),
                bad_request_error_pattern('subject', :"Has 300 characters, it can have maximum of 255 characters"),
                bad_request_error_pattern('phone', :"Has 300 characters, it can have maximum of 255 characters"),
                bad_request_error_pattern('tags', :"Should only contain elements that have maximum of 32 characters")])
    assert_response 400
  end

  def test_update_length_valid_with_trailing_spaces
    t = ticket
    params_hash = update_ticket_params_hash.merge(custom_fields: { 'test_custom_text' => Faker::Lorem.characters(20) + white_space }, name: Faker::Lorem.characters(20) + white_space, requester_id: nil, subject: Faker::Lorem.characters(20) + white_space, phone: Faker::Lorem.characters(20) + white_space, tags: [Faker::Lorem.characters(20) + white_space])
    put :update, construct_params({ id: t.display_id }, params_hash)
    params_hash[:tags].each(&:strip!)
    result = params_hash.each { |x, y| y.strip! if [:name, :subject, :phone].include?(x) }
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    assert_equal t.reload.requester.name, result[:name]
    assert_equal t.reload.requester.phone, result[:phone]
    assert_equal t.reload.subject, result[:subject]
    assert_equal t.reload.custom_field['test_custom_text_1'], params_hash[:custom_fields]['test_custom_text'].strip
  end

  def test_update_length_invalid_twitter_id
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: nil, twitter_id: Faker::Lorem.characters(300))
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json([bad_request_error_pattern('twitter_id', :"Has 300 characters, it can have maximum of 255 characters")])
    assert_response 400
  end

  def test_update_length_valid_twitter_id_with_trailing_space
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: nil, twitter_id: Faker::Lorem.characters(20) + white_space)
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    assert_equal t.reload.requester.twitter_id, params_hash[:twitter_id].strip
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_length_invalid_email
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: nil, email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(300)}.com")
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json([bad_request_error_pattern('email', :"Has 328 characters, it can have maximum of 255 characters")])
    assert_response 400
  end

  def test_update_length_valid_email_with_trailing_space
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: nil, email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(20)}.com" + white_space)
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    assert_equal t.reload.requester.email, params_hash[:email].strip
  end

  def test_update_presence_requester_id_invalid
    t = ticket
    params_hash = update_ticket_params_hash.except(:email).merge(requester_id: nil)
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('requester_id', :fill_a_mandatory_field, field_names: 'requester_id, phone, email, twitter_id, facebook_id')])
  end

  def test_update_presence_name_invalid
    t = ticket
    params_hash = update_ticket_params_hash.except(:email).merge(phone: Faker::PhoneNumber.phone_number, requester_id: nil)
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('name', :phone_mandatory)])
  end

  def test_update_email_format_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(email: 'test@', requester_id: nil)
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('email', :invalid_format, accepted: 'valid email address')])
  end

  def test_update_data_type_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(tags: 'tag1,tag2', custom_fields: [1])
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('tags', :data_type_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('custom_fields', :data_type_mismatch, expected_data_type: 'key/value pair', prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_update_date_time_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(due_by: '7/7669/0', fr_due_by: '7/9889/0')
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :invalid_format, accepted: :"combined date and time ISO8601"),
                bad_request_error_pattern('fr_due_by', :invalid_format, accepted: :"combined date and time ISO8601")])
  end

  def test_update_extra_params_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(junk: 'test')
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('junk', :invalid_field)])
  end

  def test_update_empty_params
    t = ticket
    params_hash = {}
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json(request_error_pattern(:missing_params))
  end

  def test_update_with_existing_fb_user
    t = ticket
    user = add_new_user_with_fb_id(@account)
    params_hash = update_ticket_params_hash.except(:email).merge(facebook_id: user.fb_profile_id, requester_id: nil)
    count = User.count
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    assert User.count == count
  end

  def test_update_with_existing_twitter
    user = add_new_user_with_twitter_id(@account)
    params_hash = update_ticket_params_hash.except(:email).merge(twitter_id: user.twitter_id, requester_id: nil)
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    assert User.count == count
    assert User.find(t.reload.requester_id).twitter_id == user.twitter_id
  end

  def test_update_with_existing_phone
    t = ticket
    user = add_new_user_without_email(@account)
    params_hash = update_ticket_params_hash.except(:email).merge(phone: user.phone, name: Faker::Name.name, requester_id: nil)
    count = User.count
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    assert User.count == count
    assert User.find(t.reload.requester_id).phone == user.phone
  end

  def test_update_with_existing_email
    t = ticket
    user = add_new_user(@account)
    params_hash = update_ticket_params_hash.merge(email: user.email, requester_id: nil)
    count = User.count
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(ticket_pattern(params_hash, t.reload))
    match_json(ticket_pattern({}, t))
    assert_response 200
    assert User.count == count
    assert User.find(t.reload.requester_id).email == user.email
  end

  def test_update_with_invalid_custom_fields
    t = ticket
    params_hash = update_ticket_params_hash.merge('custom_fields' => { 'dsfsdf' => 'dsfsdf' })
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('dsfsdf', :invalid_field)])
  end

  def test_update_with_nested_custom_fields_with_invalid_first_children_valid
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'uyiyiuy', 'test_custom_state' => 'Queensland', 'test_custom_city' => 'Brisbane' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_country', :not_included, list: 'Australia,USA')])
  end

  def test_update_with_nested_custom_fields_with_invalid_first_children_invalid
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'uyiyiuy', 'test_custom_state' => 'ss', 'test_custom_city' => 'ss' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_country', :not_included, list: 'Australia,USA')])
  end

  def test_update_with_nested_custom_fields_with_valid_first_invalid_second_valid_third
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'hjhj', 'test_custom_city' => 'Brisbane' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_state', :not_included, list: 'New South Wales,Queensland')])
  end

  def test_update_with_nested_custom_fields_with_valid_first_invalid_second_without_third
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'hjhj' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_state', :not_included, list: 'New South Wales,Queensland')])
  end

  def test_update_with_nested_custom_fields_with_valid_first_invalid_second_without_third_invalid_third
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'hjhj', 'test_custom_city' => 'sfs' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_state', :not_included, list: 'New South Wales,Queensland')])
  end

  def test_update_with_nested_custom_fields_with_valid_first_valid_second_invalid_third
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'Queensland', 'test_custom_city' => 'ddd' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_city', :not_included, list: 'Brisbane')])
  end

  def test_update_with_nested_custom_fields_with_valid_first_valid_second_invalid_other_third
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'Queensland', 'test_custom_city' => 'Sydney' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_city', :not_included, list: 'Brisbane')])
  end

  def test_update_with_nested_custom_fields_without_first_with_second_and_third
    t = create_ticket(requester_id: @agent.id, custom_field: { 'test_custom_country_1' => 'Australia' })
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_state' => 'Queensland', 'test_custom_city' => 'Brisbane' })
    put :update, construct_params({ id: t.display_id }, params)
    t = Helpdesk::Ticket.find(t.id)
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 200
    assert_equal t.custom_field["test_custom_state_#{@account.id}"], 'Queensland'
    assert_equal t.custom_field["test_custom_city_#{@account.id}"], 'Brisbane'
  end

  def test_update_with_nested_custom_fields_without_first_with_second_only
    t = create_ticket(requester_id: @agent.id, custom_field: { 'test_custom_country_1' => 'Australia' })
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_state' => 'Queensland' })
    put :update, construct_params({ id: t.display_id }, params)
    t = Helpdesk::Ticket.find(t.id)
    match_json(ticket_pattern(params, t.reload))
    match_json(ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.custom_field["test_custom_state_#{@account.id}"], 'Queensland'
  end

  def test_update_with_nested_custom_fields_without_first_with_third_only
    t = create_ticket(requester_id: @agent.id, custom_field: { 'test_custom_country_1' => 'Australia', 'test_custom_state_1' => 'Queensland' })
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_city' => 'Brisbane' })
    put :update, construct_params({ id: t.display_id }, params)
    t = Helpdesk::Ticket.find(t.id)
    match_json(ticket_pattern(params, t.reload))
    match_json(ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.custom_field["test_custom_city_#{@account.id}"], 'Brisbane'
  end

  def test_update_with_nested_custom_fields_without_second_with_third
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_city' => 'Brisbane' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_state', :conditional_not_blank, child: 'test_custom_city')])
  end

  def test_update_with_nested_custom_fields_required_without_second_level
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia' })
    ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
    ticket_field.update_attribute(:required, true)
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required, false)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_state', :not_included, code: :missing_field, list: 'New South Wales,Queensland')])
  end

  def test_update_with_nested_custom_fields_required_without_third_level
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'Queensland' })
    ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
    ticket_field.update_attribute(:required, true)
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required, false)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_city', :not_included, code: :missing_field, list: 'Brisbane')])
  end

  def test_update_with_nested_custom_fields_required_for_closure_without_second_level
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4, custom_fields: { 'test_custom_country' => 'Australia' })
    ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
    ticket_field.update_attribute(:required_for_closure, true)
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_state', :not_included, code: :missing_field, list: 'New South Wales,Queensland')])
  end

  def test_update_with_nested_custom_fields_required_for_closure_without_third_level
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4, custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'Queensland' })
    ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
    ticket_field.update_attribute(:required_for_closure, true)
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response 400
    match_json([bad_request_error_pattern('test_custom_city', :not_included, code: :missing_field, list: 'Brisbane')])
  end

  def test_destroy
    ticket.update_column(:deleted, false)
    delete :destroy, construct_params(id: ticket.display_id)
    assert_response 204
    assert Helpdesk::Ticket.find_by_display_id(ticket.display_id).deleted == true
  end

  def test_destroy_invalid_id
    delete :destroy, construct_params(id: '78798')
    assert_response :missing
  end

  def test_update_verify_permission_invalid_permission
    User.any_instance.stubs(:has_ticket_permission?).with(ticket).returns(false).at_most_once
    put :update, construct_params({ id: ticket.display_id }, update_ticket_params_hash)
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_update_verify_permission_ticket_trashed
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true).at_most_once
    put :update, construct_params({ id: ticket.display_id }, update_ticket_params_hash)
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_delete_has_ticket_permission_invalid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
    User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
    delete :destroy, construct_params(id: Helpdesk::Ticket.first.display_id)
    User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_delete_has_ticket_permission_valid
    t = create_ticket(ticket_params_hash)
    User.any_instance.stubs(:can_view_all_tickets?).returns(true).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
    User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
    delete :destroy, construct_params(id: t.display_id)
    User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
    assert_response 204
  end

  def test_delete_group_ticket_permission_invalid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(true).at_most_once
    User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
    Helpdesk::Ticket.stubs(:group_tickets_permission).returns([]).at_most_once
    delete :destroy, construct_params(id: Helpdesk::Ticket.first.display_id)
    User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
    Helpdesk::Ticket.unstub(:group_tickets_permission)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_delete_assigned_ticket_permission_invalid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
    User.any_instance.stubs(:assigned_ticket_permission).returns(true).at_most_once
    Helpdesk::Ticket.stubs(:assigned_tickets_permission).returns([]).at_most_once
    delete :destroy, construct_params(id: ticket.display_id)
    User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
    Helpdesk::Ticket.unstub(:assigned_tickets_permission)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_delete_group_ticket_permission_valid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(true).at_most_once
    User.any_instance.stubs(:assigned_ticket_permission).returns(false).at_most_once
    group = create_group_with_agents(@account, agent_list: [@agent.id])
    t = create_ticket(ticket_params_hash.merge(group_id: group.id))
    delete :destroy, construct_params(id: t.display_id)
    User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
    assert_response 204
  end

  def test_delete_assigned_ticket_permission_valid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
    User.any_instance.stubs(:assigned_ticket_permission).returns(true).at_most_once
    t = create_ticket(ticket_params_hash)
    Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(@agent.id)
    delete :destroy, construct_params(id: t.display_id)
    User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
    assert_response 204
    Helpdesk::Ticket.any_instance.unstub(:responder_id)
  end

  def test_restore_extra_params
    ticket.update_column(:deleted, true)
    put :restore, construct_params({ id: ticket.display_id }, test: 1)
    assert_response 400
    match_json(request_error_pattern('no_content_required'))
  end

  def test_restore_load_object_not_present
    put :restore, construct_params(id: 999)
    assert_response :missing
    assert_equal ' ', @response.body
  end

  def test_restore_without_privilege
    User.any_instance.stubs(:privilege?).with(:delete_ticket).returns(false).at_most_once
    put :restore, construct_params(id: Helpdesk::Ticket.first.display_id)
    User.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_restore_with_permission
    t = create_ticket
    t.update_column(:deleted, true)
    put :restore, construct_params(id: t.display_id)
    assert_response 204
    refute ticket.reload.deleted
  end

  def test_restore_with_ticket_trashed
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
    t = create_ticket
    t.update_column(:deleted, true)
    put :restore, construct_params(id: t.display_id)
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_restore_without_ticket_privilege
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    t = create_ticket
    t.update_column(:deleted, true)
    put :restore, construct_params(id: t.display_id)
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_show_object_not_present
    get :show, controller_params(id: 999)
    assert_response :missing
    assert_equal ' ', @response.body
  end

  def test_show_without_permission
    User.any_instance.stubs(:has_ticket_permission?).returns(false).at_most_once
    get :show, controller_params(id: Helpdesk::Ticket.first.display_id)
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_update_deleted
    ticket.update_column(:deleted, true)
    put :update, construct_params({ id: ticket.display_id }, source: 2)
    assert_response :missing
    ticket.update_column(:deleted, false)
  end

  def test_destroy_deleted
    ticket.update_column(:deleted, true)
    delete :destroy, construct_params(id: ticket.display_id)
    assert_response :missing
    ticket.update_column(:deleted, false)
  end

  def test_destroy_spammed
    ticket.update_column(:spam, true)
    delete :destroy, construct_params(id: ticket.display_id)
    assert_response :missing
    ticket.update_column(:spam, false)
  end

  def test_restore_not_deleted
    ticket.update_column(:deleted, false)
    put :restore, construct_params(id: ticket.display_id)
    assert_response :missing
  end

  def test_show
    ticket.update_column(:deleted, false)
    get :show, controller_params(id: ticket.display_id)
    assert_response 200
    match_json(ticket_pattern({}, ticket))
  end

  def test_show_with_conversations
    ticket.update_column(:deleted, false)
    get :show, controller_params(id: ticket.display_id, include: 'conversations')
    assert_response 200
    match_json(ticket_pattern_with_notes(ticket))
  end

  def test_show_with_empty_include
    ticket.update_column(:deleted, false)
    get :show, controller_params(id: ticket.display_id, include: '')
    assert_response 400
    match_json([bad_request_error_pattern('include', :not_included, list: 'conversations')])
  end

  def test_show_with_invalid_param_value
    ticket.update_column(:deleted, false)
    get :show, controller_params(id: ticket.display_id, include: 'test')
    assert_response 400
    match_json([bad_request_error_pattern('include', :not_included, list: 'conversations')])
  end

  def test_show_with_invalid_params
    ticket.update_column(:deleted, false)
    get :show, controller_params(id: ticket.display_id, includ: 'test')
    assert_response 400
    match_json([bad_request_error_pattern('includ', :invalid_field)])
  end

  def test_show_deleted
    ticket.update_column(:deleted, true)
    get :show, controller_params(id: ticket.display_id)
    assert_response 200
    match_json(deleted_ticket_pattern({}, ticket))
    ticket.update_column(:deleted, false)
  end

  def test_index_without_permitted_tickets
    Helpdesk::Ticket.update_all(responder_id: nil)
    get :index, controller_params(per_page: 50)
    assert_response 200
    response = parse_response @response.body
    assert_equal Helpdesk::Ticket.where(deleted: 0, spam: 0).created_in(Helpdesk::Ticket.created_in_last_month).count, response.size

    Agent.any_instance.stubs(:ticket_permission).returns(3)
    get :index, controller_params
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    Helpdesk::Ticket.where(deleted: 0, spam: 0).first.update_attributes(responder_id: @agent.id, created_at: Time.zone.now)
    get :index, controller_params
    assert_response 200
    Agent.any_instance.unstub(:ticket_permission)
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_invalid_sort_params
    get :index, controller_params(order_type: 'test', order_by: 'priority')
    assert_response 400
    pattern = [bad_request_error_pattern('order_type', :not_included, list: 'asc,desc')]
    pattern << bad_request_error_pattern('order_by', :not_included, list: 'due_by,created_at,updated_at,status')
    match_json(pattern)
  end

  def test_index_with_extra_params
    hash = { filter_name: 'test', company_name: 'test' }
    get :index, controller_params(hash)
    assert_response 400
    pattern = []
    hash.keys.each { |key| pattern << bad_request_error_pattern(key, :invalid_field) }
    match_json pattern
  end

  def test_index_with_invalid_params
    get :index, controller_params(company_id: 999, requester_id: '999', filter: 'x')
    pattern = [bad_request_error_pattern('filter', :not_included, list: 'new_and_my_open,watching,spam,deleted')]
    pattern << bad_request_error_pattern('company_id', :invalid_value, resource: :company, attribute: :company_id)
    pattern << bad_request_error_pattern('requester_id', :invalid_value, resource: :contact, attribute: :requester_id)
    assert_response 400
    match_json pattern
  end

  def test_index_with_invalid_email_in_params
    get :index, controller_params(email: Faker::Internet.email)
    pattern = [bad_request_error_pattern('email', :invalid_value, resource: :contact, attribute: :email)]
    assert_response 400
    match_json pattern
  end

  def test_index_with_invalid_params_type
    get :index, controller_params(company_id: 'a', requester_id: 'b')
    pattern = [bad_request_error_pattern('company_id', :data_type_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)]
    pattern << bad_request_error_pattern('requester_id', :data_type_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)
    assert_response 400
    match_json pattern
  end

  def test_index_with_monitored_by
    get :index, controller_params(filter: 'watching')
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.count

    subscription = FactoryGirl.build(:subscription, account_id: @account.id,
                                                    ticket_id: Helpdesk::Ticket.first.id,
                                                    user_id: @agent.id)
    subscription.save
    get :index, controller_params(filter: 'watching')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.count
  end

  def test_index_with_new_and_my_open
    Helpdesk::Ticket.update_all(status: 3)
    Helpdesk::Ticket.first.update_attributes(status: 2, responder_id: @agent.id,
                                             deleted: false, spam: false)
    get :index, controller_params(filter: 'new_and_my_open')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_default_filter
    Helpdesk::Ticket.update_all(created_at: 2.months.ago)
    Helpdesk::Ticket.first.update_attributes(created_at: 1.months.ago,
                                             deleted: false, spam: false)
    get :index, controller_params
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_default_filter_order_type
    Helpdesk::Ticket.update_all(created_at: 2.months.ago)
    Helpdesk::Ticket.first.update_attributes(created_at: 1.months.ago,
                                             deleted: false, spam: false)
    get :index, controller_params(order_type: 'asc')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_default_filter_order_by
    Helpdesk::Ticket.update_all(created_at: 2.months.ago)
    Helpdesk::Ticket.first(2).each do|x|
      x.update_attributes(created_at: 1.months.ago,
                          deleted: false, spam: false)
    end
    get :index, controller_params(order_by: 'status')
    assert_response 200
    response = parse_response @response.body
    assert_equal 2, response.size
  end

  def test_index_with_spam
    get :index, controller_params(filter: 'spam')
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    Helpdesk::Ticket.first.update_attributes(spam: true, created_at: 2.months.ago)
    get :index, controller_params(filter: 'spam')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_deleted
    tkts = Helpdesk::Ticket.select { |x| x.deleted && !x.schema_less_ticket.boolean_tc02 }
    t = ticket
    t.update_column(:deleted, true)
    t.update_column(:spam, true)
    t.update_column(:created_at, 2.months.ago)
    tkts << t.reload
    get :index, controller_params(filter: 'deleted')
    pattern = []
    tkts.each { |tkt| pattern << index_deleted_ticket_pattern(tkt) }
    match_json(pattern)

    t.update_column(:deleted, false)
    t.update_column(:spam, false)
    assert_response 200
  end

  def test_index_with_requester
    Helpdesk::Ticket.update_all(requester_id: User.first.id)
    ticket = create_ticket(requester_id: User.last.id)
    ticket.update_column(:created_at, 2.months.ago)
    get :index, controller_params(requester_id: "#{User.last.id}")
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.count
    set_wrap_params
  end

  def test_index_with_filter_and_requester_email
    user = add_new_user(@account)

    get :index, controller_params(filter: 'new_and_my_open', email: user.email)
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.count

    Helpdesk::Ticket.where(deleted: 0, spam: 0).first.update_attributes(requester_id: user.id, status: 2)
    get :index, controller_params(filter: 'new_and_my_open', email: user.email)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.count
  end

  def test_index_with_company
    company = create_company
    user = User.first
    user.update_attributes(customer_id: company.id)
    get :index, controller_params(company_id: "#{company.id}")
    assert_response 200

    tkts = Helpdesk::Ticket.where(requester_id: user.id)
    pattern = tkts.map { |tkt| index_ticket_pattern(tkt) }
    match_json(pattern)
  end

  def test_index_with_filter_and_requester
    user = add_new_user(@account)
    requester = User.first
    Helpdesk::Ticket.update_all(requester_id: user.id)
    get :index, controller_params(filter: 'new_and_my_open', requester_id: "#{requester.id}")
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.count

    Helpdesk::Ticket.where(deleted: 0, spam: 0).first.update_attributes(requester_id: requester.id, status: 2)
    get :index, controller_params(filter: 'new_and_my_open', requester_id: "#{requester.id}")
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.count
  end

  def test_index_with_filter_and_company
    Helpdesk::Ticket.update_all(status: 3)
    get :index, controller_params(filter: 'new_and_my_open', company_id: "#{Company.first.id}")
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.count

    user_id = Company.first.users.map(&:id).first
    tkt = Helpdesk::Ticket.first
    tkt.update_attributes(status: 2, requester_id: user_id, responder_id: nil)
    get :index, controller_params(filter: 'new_and_my_open', company_id: "#{Company.first.id}")
    assert_response 200
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
    get :index, controller_params(company_id: company.id, requester_id: "#{user1.id}")
    assert_response 200
    response = parse_response @response.body
    assert_equal expected_size, response.size

    user2.update_column(:customer_id, nil)
    get :index, controller_params(company_id: company.id, requester_id: "#{user2.id}")
    assert_response 200
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
                                  requester_id: "#{User.first.id}", filter: 'new_and_my_open')
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    user_id = company.users.map(&:id).first
    Helpdesk::Ticket.where(deleted: 0, spam: 0).first.update_attributes(requester_id: user_id,
                                                                        status: 2, responder_id: nil)
    get :index, controller_params(company_id: company.id,
                                  requester_id: "#{user_id}", filter: 'new_and_my_open')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_dates
    get :index, controller_params(updated_since: Time.zone.now.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    tkt = Helpdesk::Ticket.first
    tkt.update_column(:created_at, 1.days.from_now)
    get :index, controller_params(updated_since: Time.zone.now.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    tkt.update_column(:updated_at, 1.days.from_now)
    get :index, controller_params(updated_since: Time.zone.now.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_time_zone
    tkt = Helpdesk::Ticket.where(deleted: false, spam: false).first
    old_time_zone = Time.zone.name
    Time.zone = 'Chennai'
    get :index, controller_params(updated_since: tkt.updated_at.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert response.size > 0
    assert response.map { |item| item['ticket_id'] }
    Time.zone = old_time_zone
  end

  def test_show_with_conversations_exceeding_limit
    ticket.update_column(:deleted, false)
    4.times do
      create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
    end
    stub_const(ConversationConstants, 'MAX_INCLUDE', 3) do
      get :show, controller_params(id: ticket.display_id, include: 'conversations')
    end
    match_json(ticket_pattern_with_notes(ticket, 3))
    assert_response 200
    response = parse_response @response.body
    assert_equal 3, response['conversations'].size
    assert ticket.reload.notes.visible.exclude_source('meta').size > 3
  end

  def test_show_spam
    t = ticket
    t.update_column(:spam, true)
    get :show, controller_params(id: t.display_id)
    match_json(ticket_pattern({}, ticket))
    assert_response 200
    t.update_column(:spam, false)
  end

  def test_delete_spam
    t = ticket
    t.update_column(:spam, true)
    delete :destroy, controller_params(id: t.display_id)
    assert_response :missing
    t.update_column(:spam, false)
  end

  def test_update_spam
    t = ticket
    t.update_column(:spam, true)
    put :update, construct_params({ id: t.display_id }, update_ticket_params_hash)
    assert_response :missing
    t.update_column(:spam, false)
  end

  def test_restore_spam
    t = create_ticket
    t.update_column(:deleted, true)
    t.update_column(:spam, true)
    put :restore, construct_params(id: t.display_id)
    assert_response :missing
    t.update_column(:spam, false)
  end

  def test_update_array_fields_with_empty_array
    params_hash = update_ticket_params_hash
    t = create_ticket
    put :update, construct_params({ id: t.display_id }, tags: [])
    match_json(ticket_pattern({}, t.reload))
    assert_response 200
  end

  def test_update_array_fields_with_invalid_tags_and_nil_custom_field
    params_hash = update_ticket_params_hash
    t = create_ticket
    put :update, construct_params({ id: t.display_id }, tags: [1, 2], custom_fields: {})
    match_json([bad_request_error_pattern('tags', :array_data_type_mismatch, expected_data_type: String)])
    assert_response 400
  end

  def test_update_array_fields_with_compacting_array
    tag = Faker::Name.name
    params_hash = update_ticket_params_hash
    t = ticket
    put :update, construct_params({ id: t.display_id }, tags: [tag, '', ''])
    match_json(ticket_pattern({ tags: [tag] }, t.reload))
    assert_response 200
  end

  def test_index_with_link_header
    create_ticket(requester_id: @agent.id)
    per_page = Helpdesk::Ticket.where(deleted: 0, spam: 0).created_in(Helpdesk::Ticket.created_in_last_month).count - 1
    get :index, controller_params(per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/tickets?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(per_page: per_page, page: 2)
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
    assert_response 200
  end

  def test_update_due_by_without_time_zone_fr_due_by_with_time_zone
    params_hash = {}
    t = ticket
    due_by = 5.hours.since.utc.iso8601
    fr_due_by = 3.hours.since.to_time.in_time_zone('Tokelau Is.')
    t.update_attributes(manual_dueby: Time.zone.now.iso8601)
    put :update, construct_params({ id: t.display_id }, due_by: due_by.chop,
                                                        fr_due_by: fr_due_by.iso8601)
    match_json(ticket_pattern({ due_by: due_by, fr_due_by: fr_due_by.utc.iso8601 }, t.reload))
    assert_response 200
  end

  def test_create_with_all_default_fields_required_invalid
    default_non_required_fiels = Helpdesk::TicketField.where(required: false, default: 1)
    default_non_required_fiels.map { |x| x.toggle!(:required) }
    post :create, construct_params({},  requester_id: @agent.id)
    match_json([bad_request_error_pattern('description', :data_type_mismatch, code: :missing_field, expected_data_type: String),
                bad_request_error_pattern('subject', :data_type_mismatch, code: :missing_field, expected_data_type: String),
                bad_request_error_pattern('group_id', :data_type_mismatch, code: :missing_field, expected_data_type: 'Positive Integer'),
                bad_request_error_pattern('responder_id', :data_type_mismatch, code: :missing_field, expected_data_type: 'Positive Integer'),
                bad_request_error_pattern('product_id', :data_type_mismatch, code: :missing_field, expected_data_type: 'Positive Integer'),
                bad_request_error_pattern('priority', :not_included, code: :missing_field, list: '1,2,3,4'),
                bad_request_error_pattern('status', :not_included, code: :missing_field, list: '2,3,4,5,6,7'),
                bad_request_error_pattern('type', :not_included, code: :missing_field, list: 'Question,Incident,Problem,Feature Request,Lead'),
                bad_request_error_pattern('source', :not_included, code: :missing_field, list: '1,2,3,7,8,9')])
    assert_response 400
  ensure
    default_non_required_fiels.map { |x| x.toggle!(:required) }
  end

  def test_create_with_all_default_fields_required_valid
    default_non_required_fiels = Helpdesk::TicketField.where(required: false, default: 1)
    default_non_required_fiels.map { |x| x.toggle!(:required) }
    product = create_product
    post :create, construct_params({},  requester_id: @agent.id,
                                        status: 2,
                                        priority: 2,
                                        type: 'Lead',
                                        source: 1,
                                        description: Faker::Lorem.characters(15),
                                        group_id: ticket_params_hash[:group_id],
                                        responder_id: ticket_params_hash[:responder_id],
                                        product_id: product.id,
                                        subject: Faker::Lorem.characters(15)
                                  )
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    assert_response 201
  ensure
    default_non_required_fiels.map { |x| x.toggle!(:required) }
  end

  def test_update_with_all_default_fields_required_invalid
    default_non_required_fiels = Helpdesk::TicketField.where(required: false, default: 1)
    default_non_required_fiels.map { |x| x.toggle!(:required) }
    put :update, construct_params({ id: ticket.id },  subject: nil,
                                                      description: nil,
                                                      group_id: nil,
                                                      product_id: nil,
                                                      responder_id: nil,
                                                      status: nil,
                                                      priority: nil,
                                                      source: nil,
                                                      type: nil
                                 )
    match_json([bad_request_error_pattern('description',  :data_type_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Null Type'),
                bad_request_error_pattern('subject',  :data_type_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Null Type'),
                bad_request_error_pattern('group_id', :data_type_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'Null Type'),
                bad_request_error_pattern('responder_id', :data_type_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'Null Type'),
                bad_request_error_pattern('product_id', :data_type_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'Null Type'),
                bad_request_error_pattern('priority', :not_included, list: '1,2,3,4'),
                bad_request_error_pattern('status', :not_included, list: '2,3,4,5,6,7'),
                bad_request_error_pattern('type', :not_included, list: 'Question,Incident,Problem,Feature Request,Lead'),
                bad_request_error_pattern('source', :not_included, list: '1,2,3,7,8,9')])
    assert_response 400
  ensure
    default_non_required_fiels.map { |x| x.toggle!(:required) }
  end

  def test_create_with_email_array
    post :create, construct_params({}, ticket_params_hash.except(:email).merge(email: [email: Faker::Internet.email]))
    assert_response 400
    match_json([bad_request_error_pattern('email', :data_type_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_update_with_email_array
    params_hash = { email: [Faker::Internet.email] }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('email', :data_type_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_create_ticket_with_twitter_and_invalid_email
    create_ticket(ticket_params_hash.except(:email).merge(twitter_id: '@test123'))
    params = { email: Faker::Name.name, status: 2, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph, twitter_id: '@test123' }
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('email', :invalid_format, accepted: 'valid email address')])
  end
end
