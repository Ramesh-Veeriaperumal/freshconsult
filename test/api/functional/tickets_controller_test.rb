
require_relative '../test_helper'
require 'sidekiq/testing'
require 'webmock/minitest'
require Rails.root.join('test', 'api', 'helpers', 'privileges_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'advanced_scope_test_helper.rb')
['social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['shared_ownership_test_helper'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

Sidekiq::Testing.fake!

class TicketsControllerTest < ActionController::TestCase
  include ApiTicketsTestHelper
  include CustomFieldsTestHelper
  include AttachmentsTestHelper
  include AwsTestHelper
  include CannedResponsesTestHelper
  include SharedOwnershipTestHelper
  include SlaPoliciesTestHelper
  include ::SocialTestHelper
  include ::SocialTicketsCreationHelper
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Constant
  include PrivilegesHelper
  include FieldServiceManagementTestHelper
  include AdvancedScopeTestHelper
  CUSTOM_FIELDS = %w(number checkbox decimal text paragraph dropdown country state city date)

  VALIDATABLE_CUSTOM_FIELDS =  %w(number checkbox decimal text paragraph date)

  CUSTOM_FIELDS_VALUES = { 'country' => 'USA', 'state' => 'California', 'city' => 'Burlingame', 'number' => 32_234, 'decimal' => '90.89', 'checkbox' => true, 'text' => Faker::Name.name, 'paragraph' =>  Faker::Lorem.paragraph, 'dropdown' => 'Pursuit of Happiness', 'date' => '2015-09-09' }
  UPDATE_CUSTOM_FIELDS_VALUES = { 'country' => 'Australia', 'state' => 'Queensland', 'city' => 'Brisbane', 'number' => 12, 'decimal' => '8900.89',  'checkbox' => false, 'text' => Faker::Name.name, 'paragraph' =>  Faker::Lorem.paragraph, 'dropdown' => 'Armaggedon', 'date' => '2015-09-09' }
  CUSTOM_FIELDS_VALUES_INVALID = { 'number' => '1.90', 'decimal' => 'dd', 'checkbox' => 'iu', 'text' => Faker::Lorem.characters(300), 'paragraph' =>  12_345, 'date' => '31-13-09' }
  UPDATE_CUSTOM_FIELDS_VALUES_INVALID = { 'number' => '1.89', 'decimal' => 'addsad', 'checkbox' => 'nmbm', 'text' => Faker::Lorem.characters(300), 'paragraph' =>  3_543_534, 'date' => '2015-09-09T09:00' }
  UPDATE_NESTED_FIELD_VALUES = { 'country' => 'USA', 'state' => 'Texas', 'city' => 'Austin' }.freeze

  ERROR_PARAMS =  {
      'number' => [:datatype_mismatch, expected_data_type: 'Integer', prepend_msg: :input_received, given_data_type: String],
      'decimal' => [:datatype_mismatch, expected_data_type: 'Number'],
      'checkbox' => [:datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String],
      'text' => [:'Has 300 characters, it can have maximum of 255 characters'],
      'paragraph' => [:datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer],
      'date' => [:invalid_date, accepted: 'yyyy-mm-dd']
  }

  ERROR_REQUIRED_PARAMS  =  {
      'number' => [:datatype_mismatch, { code: :missing_field, expected_data_type: :Integer }],
      'decimal' => [:datatype_mismatch, { code: :missing_field, expected_data_type: :Number }],
      'checkbox' => [:datatype_mismatch, { code: :missing_field, expected_data_type: :Boolean }],
      'text' => [:datatype_mismatch, { code: :missing_field, expected_data_type: :String }],
      'paragraph' => [:datatype_mismatch, { code: :missing_field, expected_data_type: :String }],
      'date' => [:invalid_date, { code: :missing_field, accepted: 'yyyy-mm-dd' }]
  }
  ERROR_CHOICES_REQUIRED_PARAMS  =  {
      'dropdown' => [:not_included, { code: :missing_field, list: 'Get Smart,Pursuit of Happiness,Armaggedon' }],
      'country' => [:not_included, { code: :missing_field, list: 'Australia,USA' }]
  }

  def setup
    CustomRequestStore.store[:private_api_request] = false
    super
    Sidekiq::Worker.clear_all
    before_all
    destroy_all_fsm_fields_and_service_task_type
  end

  @@before_all_run = false

  def before_all
    @account.sections.map(&:destroy)
    return if @@before_all_run
    @account.ticket_fields.custom_fields.each(&:destroy)
    Helpdesk::TicketStatus.find(2).update_column(:stop_sla_timer, false)
    @@ticket_fields = []
    @@custom_field_names = []
    @@ticket_fields << create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city], Random.rand(10..20))
    @@ticket_fields << create_custom_field_dropdown('test_custom_dropdown', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
    @@choices_custom_field_names = @@ticket_fields.map(&:name)
    CUSTOM_FIELDS.each do |custom_field|
      next if %w(dropdown country state city).include?(custom_field)
      @@ticket_fields << create_custom_field("test_custom_#{custom_field}", custom_field)
      @@custom_field_names << @@ticket_fields.last.name
    end
    @account.launch :add_watcher
    @account.time_zone = Time.zone.name
    @account.save
    @account.revoke_feature :unique_contact_identifier
    Helpdesk::TicketField.where(name: ['requester', 'subject', 'description', 'status', 'priority']).update_all(required: true)
    @@before_all_run = true
  end

  def destroy_all_fsm_fields_and_service_task_type
    fsm_fields = fsm_custom_field_to_reserve.collect { |x| x[:name] + "_#{@account.id}" }
    fsm_fields.each do |fsm_field|
			@account.ticket_fields.find_by_name(fsm_field).try(:destroy)
		end
    @account.picklist_values.find_by_value(SERVICE_TASK_TYPE).try(:destroy)
  end

  def wrap_cname(params = {})
    query_params = params[:query_params]
    cparams = params.clone
    cparams.delete(:query_params)
    return query_params.merge(ticket: cparams) if query_params

    { ticket: cparams }
  end

  def requester
    user = User.find { |x| x.id != @agent.id && x.helpdesk_agent == false && x.deleted == 0 && x.blocked == 0 } || add_new_user(@account)
    user
  end

  def get_user_with_multiple_companies
    user_company = @account.user_companies.group(:user_id).having(
        'count(user_id) > 1 '
    ).last
    if user_company.present?
      user_company.user
    else
      new_user = add_new_user(@account)
      new_user.user_companies.create(:company_id => get_company.id, :default => true)
      other_company = create_company
      new_user.user_companies.create(:company_id => other_company.id)
      new_user.reload
    end
  end

  def get_user_with_default_company
    user_company = @account.user_companies.group(:user_id).having('count(*) = 1 ').last
    if user_company.present?
      user_company.user
    else
      new_user = add_new_user(@account)
      new_user.user_companies.create(:company_id => get_company.id, :default => true)
      new_user.reload
    end
  end

  def get_company
    company = Company.first
    return company if company
    company = Company.create(name: Faker::Name.name, account_id: @account.id)
    company.save
    company
  end

  def ticket_type_list
    ticket_type = 'Question,Incident,Problem,Feature Request,Refund'
    ticket_type << ",#{SERVICE_TASK_TYPE}" if Account.current.picklist_values.map(&:value).include?(SERVICE_TASK_TYPE)
    ticket_type
  end


  def fetch_email_config
    @account.email_configs.where('active = true').first || create_email_config
  end

  def ticket
    ticket = Helpdesk::Ticket.where('source != ?', 10).last || create_ticket(ticket_params_hash)
    ticket
  end

  def update_ticket_params_hash
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    subject = Faker::Lorem.words(10).join(' ')
    description = Faker::Lorem.paragraph
    @update_group ||= create_group_with_agents(@account, agent_list: [agent.id])
    params_hash = { description: description, subject: subject, priority: 4, status: 7, type: 'Incident',
                    responder_id: agent.id, source: 3, tags: ['update_tag1', 'update_tag2'],
                    due_by: 12.days.since.iso8601, fr_due_by: 4.days.since.iso8601, group_id: @update_group.id }
    params_hash
  end

  def ticket_params_hash
    cc_emails = [Faker::Internet.email, Faker::Internet.email, "\"#{Faker::Name.name}\" <#{Faker::Internet.email}>"]
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

  def construct_sections(field_name)
    if field_name == 'type'
      sections = [{ title: 'section1',
                    value_mapping: %w[Question Problem],
                    ticket_fields: %w[test_custom_number test_custom_date]
                  },
                  { title: 'section2',
                    value_mapping: ['Incident'],
                    ticket_fields: %w[test_custom_paragraph test_custom_dropdown]
                  }]
    else
      sections = [{ title: 'section1',
                    value_mapping: %w[Choice\ 1 Choice\ 2],
                    ticket_fields: %w[test_custom_number test_custom_date]
                  },
                  { title: 'section2',
                    value_mapping: ['Choice 3'],
                    ticket_fields: %w[test_custom_paragraph]
                  }]
    end
    sections
  end

  def enable_skip_mandatory_checks_option
    @@admin_tasks_privilege_present = User.current.privilege?(:admin_tasks)
    @@skip_mandatory_checks_enabled = @account.skip_mandatory_checks_enabled?
    add_privilege(User.current, :admin_tasks) unless @@admin_tasks_privilege_present
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = true unless @@skip_mandatory_checks_enabled
    @controller.stubs(:public_api?).returns(true)
  end

  def disable_skip_mandatory_checks_option
    remove_privilege(User.current, :admin_tasks) unless @@admin_tasks_privilege_present
    @controller.unstub(:public_api?)
    @account.account_additional_settings.additional_settings.tap { |additional_settings| additional_settings.delete(:skip_mandatory_checks) } unless @@skip_mandatory_checks_enabled
  end

  def match_query_response_with_es_enabled(query_hash_params, order_by = 'created_at', order_type = 'desc')
    enable_public_api_filter_factory([:public_api_filter_factory, :new_es_api, :count_service_es_reads]) do
      response_stub = public_api_filter_factory_es_cluster_response_stub(query_hash_params.deep_dup)
      SearchService::Client.any_instance.stubs(:query).returns(SearchService::Response.new(response_stub))
      SearchService::Response.any_instance.stubs(:records).returns(JSON.parse(response_stub))
      get :index, controller_params(query_hash_params.deep_dup)
      assert_equal JSON.parse(@response.body).count, query_hash_params[:per_page] if query_hash_params[:per_page]
      match_json(public_api_ticket_index_query_hash_pattern(query_hash_params.deep_dup, order_by, order_type))
    end
  end

  def match_order_query_with_es_enabled(order_params, all_tickets = false)
    enable_public_api_filter_factory([:public_api_filter_factory, :new_es_api, :count_service_es_reads]) do
      response_stub = public_api_filter_factory_order_response_stub(order_params[:order_by], order_params[:order_type], all_tickets)
      SearchService::Client.any_instance.stubs(:query).returns(SearchService::Response.new(response_stub))
      SearchService::Response.any_instance.stubs(:records).returns(JSON.parse(response_stub))
      get :index, controller_params(order_params)
      assert_response 200
      match_json(public_api_ticket_index_pattern(false, false, false, order_params[:order_by], order_params[:order_type], all_tickets))
    end
  end

  def test_search_with_feature_enabled_and_invalid_params
    @account.launch :es_count_writes
    @account.launch :list_page_new_cluster
    params = ticket_params_hash.except(:description).merge(custom_field: {})
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_field]["test_custom_#{custom_field}_#{@account.id}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    t = create_ticket(params)
    @account.launch :api_search_beta
    get :search, controller_params(:status => '2,3', :priority => 4, 'test_custom_text' => params[:custom_field]["test_custom_text_#{@account.id}"])
    assert_response 400
  end

  def test_search_with_feature_enabled_and_invalid_value
    @account.launch :es_count_writes
    @account.launch :list_page_new_cluster
    params = ticket_params_hash.except(:description).merge(custom_field: {})
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_field]["test_custom_#{custom_field}_#{@account.id}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    t = create_ticket(params)
    @account.launch :api_search_beta
    get :search, controller_params(:status => '2,3,test1', 'test_custom_text' => params[:custom_field]["test_custom_text_#{@account.id}"])
    assert_response 400
  end

  def test_search_without_feature_enabled
    params = ticket_params_hash.except(:description).merge(custom_field: {})
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_field]["test_custom_#{custom_field}_#{@account.id}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    t = create_ticket(params)
    @account.rollback :api_search_beta
    get :search, controller_params(:status => '2,3', 'test_custom_text' => params[:custom_field]["test_custom_text_#{@account.id}"])
    assert_response 404
  end

  def test_create
    params = ticket_params_hash.merge(custom_fields: {}, description: '<b>test</b>')
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    post :create, construct_params({}, params)
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    result = parse_response(@response.body)
    assert_equal true, response.headers.include?('Location')
    assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
    assert_response 201
    assert_equal '<b>test</b>', Helpdesk::Ticket.last.description_html
    assert_equal 'test', Helpdesk::Ticket.last.description
    assert_equal result['nr_due_by'], nil
    assert_equal result['nr_escalated'], false
  ensure
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_description_html_only_tags
    params = ticket_params_hash.merge(custom_fields: {}, description: '<b></b>')
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({}, params)
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    result = parse_response(@response.body)
    assert_equal true, response.headers.include?('Location')
    assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
    assert_response 201
    assert_equal '<b></b>', Helpdesk::Ticket.last.description_html
    assert_equal '', Helpdesk::Ticket.last.description
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

  # test coverage for ticket creation without default mandatory fields other than for subject, description and requester with skip_mandatory_checks enabled for current user having :admin_tasks privilege thorough public API only

  def test_create_ticket_without_status_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = { requester_id: User.current.id, priority: 1, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_equal t.status, 2
    assert_response 201
    disable_skip_mandatory_checks_option
  end

  def test_create_ticket_without_priority_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = { requester_id: User.current.id, status: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_equal t.priority, 1
    assert_response 201
    disable_skip_mandatory_checks_option
  end

  def test_create_ticket_without_status_and_priority_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = { requester_id: User.current.id, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_equal t.priority, 1
    assert_equal t.status, 2
    assert_response 201
    disable_skip_mandatory_checks_option
  end

  def test_create_ticket_without_mandatory_type_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash.except(:type)
    Helpdesk::TicketField.where(name: 'ticket_type').update_all(required: true)
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 201
    assert_nil t.ticket_type
    Helpdesk::TicketField.where(name: 'ticket_type').update_all(required: false)
    disable_skip_mandatory_checks_option
  end

  def test_create_ticket_without_mandatory_group_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash.except(:group_id)
    Helpdesk::TicketField.where(name: 'group').update_all(required: true)
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 201
    assert_nil t.group
    Helpdesk::TicketField.where(name: 'group').update_all(required: false)
    disable_skip_mandatory_checks_option
  end

  def test_create_ticket_without_mandatory_agent_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash.except(:responder_id)
    Helpdesk::TicketField.where(name: 'agent').update_all(required: true)
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 201
    assert_nil t.agent
    Helpdesk::TicketField.where(name: 'agent').update_all(required: false)
    disable_skip_mandatory_checks_option
  end

  def test_create_ticket_without_mandatory_product_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash.except(:product_id)
    Helpdesk::TicketField.where(name: 'product').update_all(required: true)
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 201
    assert_nil t.product
    Helpdesk::TicketField.where(name: 'product').update_all(required: false)
    disable_skip_mandatory_checks_option
  end

  def test_create_ticket_without_mandatory_default_fields_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = { requester_id: User.current.id, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    Helpdesk::TicketField.where(default: true).update_all(required: true)
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 201
    assert_equal t.priority, 1
    assert_equal t.status, 2
    assert_nil t.ticket_type
    assert_nil t.group
    assert_nil t.product
    assert_nil t.agent
    Helpdesk::TicketField.where(default: true).update_all(required: false)
    Helpdesk::TicketField.where(name: 'subject', name: 'description', name: 'status', name: 'priority', name: 'requester').update_all(required: true)
    disable_skip_mandatory_checks_option
  end

   # test coverage for ticket creation without mandatory custom fields when skip_mandatory_checks is enabled for current user having :admin_tasks privilege thorough public API only

  def test_create_ticket_without_mandatory_custom_dropdown_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: "test_custom_dropdown_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 201
    disable_adv_ticketing
    Helpdesk::TicketField.where(name: "test_custom_dropdown_#{@account.id}").update_all(required: false)
  end

  def test_create_ticket_without_mandatory_custom_text_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: "test_custom_text_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 201
    disable_adv_ticketing
    Helpdesk::TicketField.where(name: "test_custom_text_#{@account.id}").update_all(required: false)
  end

  def test_create_ticket_without_mandatory_custom_number_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: "test_custom_number_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 201
    disable_adv_ticketing
    Helpdesk::TicketField.where(name: "test_custom_number_#{@account.id}").update_all(required: false)
  end

  def test_create_ticket_without_mandatory_custom_checkbox_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: "test_custom_checkbox_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 201
    disable_adv_ticketing
    Helpdesk::TicketField.where(name: "test_custom_checkbox_#{@account.id}").update_all(required: false)
  end

  def test_create_ticket_without_mandatory_custom_date_with_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: "test_custom_date_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 201
    disable_adv_ticketing
    Helpdesk::TicketField.where(name: "test_custom_date_#{@account.id}").update_all(required: false)
  end

  def test_create_ticket_without_mandatory_custom_paragraph_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: "test_custom_paragraph_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 201
    disable_adv_ticketing
    Helpdesk::TicketField.where(name: "test_custom_paragraph_#{@account.id}").update_all(required: false)
  end

  def test_create_ticket_without_mandatory_custom_decimal_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: "test_custom_decimal_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 201
    disable_adv_ticketing
    Helpdesk::TicketField.where(name: "test_custom_decimal_#{@account.id}").update_all(required: false)
  end

  def test_create_ticket_without_mandatory_custom_fields_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 201
    disable_adv_ticketing
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
  end

  # test coverage for ticket creation without mandatory fields through public API with skip_mandatory_checks enabled for current user having :admin_tasks privilege

  def test_create_ticket_without_mandatory_fields_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = { requester_id: User.current.id, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    Helpdesk::TicketField.where(default: true).update_all(required: true)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
    post :create, construct_params({}, params)
    t = @account.tickets.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_response 201
    assert_equal t.priority, 1
    assert_equal t.status, 2
    assert_equal t.source, 2
    assert_nil t.ticket_type
    assert_nil t.group
    assert_nil t.company
    assert_nil t.product
    assert_nil t.agent
    assert_nil t.custom_field["test_custom_number_#{@account.id}"]
    assert_nil t.custom_field["test_custom_text_#{@account.id}"]
    assert_nil t.custom_field["test_custom_dropdown_#{@account.id}"]
    assert_nil t.custom_field["test_custom_decimal_#{@account.id}"]
    assert_equal t.custom_field["test_custom_checkbox_#{@account.id}"], false
    assert_nil t.custom_field["test_custom_paragraph_#{@account.id}"]
    Helpdesk::TicketField.where(default: true).update_all(required: false)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
    disable_skip_mandatory_checks_option
  end

   # test coverage for ticket creation without default mandatory fields through public API wihout skip_mandatory_checks enabled for current user having :admin_tasks privilege

  def test_create_ticket_without_status_and_without_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    Helpdesk::TicketField.where(name: 'status').update_all(required: true)
    params = { email: Faker::Internet.email, priority: 1, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('status', :not_included, code: :missing_field, list: '2,3,4,5,6,7')])
    assert_response 400
    Helpdesk::TicketField.where(name: 'status').update_all(required: false)
    disable_skip_mandatory_checks_option
  end

  def test_create_ticket_without_priority_and_without_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    Helpdesk::TicketField.where(name: 'priority').update_all(required: true)
    params = { email: Faker::Internet.email, status: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('priority', :not_included, code: :missing_field, list: '1,2,3,4')])
    assert_response 400
    Helpdesk::TicketField.where(name: 'priority').update_all(required: false)
    disable_skip_mandatory_checks_option
  end

  def test_create_ticket_without_priority_and_status_and_without_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    Helpdesk::TicketField.where(name: ['priority', 'status']).update_all(required: true)
    params = { email: Faker::Internet.email, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('priority', :not_included, code: :missing_field, list: '1,2,3,4'),
                bad_request_error_pattern('status', :not_included, code: :missing_field, list: '2,3,4,5,6,7')])
    assert_response 400
    Helpdesk::TicketField.where(name: 'status', name: 'priority').update_all(required: false)
    disable_skip_mandatory_checks_option
  end

  def test_create_ticket_without_mandatory_type_without_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    params = ticket_params_hash.except(:type)
    Helpdesk::TicketField.where(name: 'ticket_type').update_all(required: true)
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('type', :not_included, code: :missing_field, list: ticket_type_list)])
    assert_response 400
    Helpdesk::TicketField.where(name: 'ticket_type').update_all(required: false)
    disable_skip_mandatory_checks_option
  end

  def test_create_ticket_without_mandatory_group_without_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    params = ticket_params_hash.except(:group_id)
    Helpdesk::TicketField.where(name: 'group').update_all(required: true)
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('group_id', :datatype_mismatch, code: :missing_field, expected_data_type: 'Positive Integer')])
    assert_response 400
    Helpdesk::TicketField.where(name: 'group').update_all(required: false)
    disable_skip_mandatory_checks_option
  end

  def test_create_ticket_without_mandatory_agent_without_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    params = ticket_params_hash.except(:responder_id)
    Helpdesk::TicketField.where(name: 'agent').update_all(required: true)
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('responder_id', :datatype_mismatch, code: :missing_field, expected_data_type: 'Positive Integer')])
    assert_response 400
    Helpdesk::TicketField.where(name: 'agent').update_all(required: false)
    disable_skip_mandatory_checks_option
  end

  def test_create_ticket_without_mandatory_product_without_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    params = ticket_params_hash.except(:product_id)
    Helpdesk::TicketField.where(name: 'product').update_all(required: true)
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('product_id', :datatype_mismatch, code: :missing_field, expected_data_type: 'Positive Integer')])
    assert_response 400
    Helpdesk::TicketField.where(name: 'product').update_all(required: false)
    disable_skip_mandatory_checks_option
  end

  def test_create_ticket_without_mandatory_default_fields_without_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    params = { requester_id: User.current.id, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    Helpdesk::TicketField.where(default: true).update_all(required: true)
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('status', :not_included, code: :missing_field, list: '2,3,4,5,6,7'),
                bad_request_error_pattern('priority', :not_included, code: :missing_field, list: '1,2,3,4'),
                bad_request_error_pattern('group_id', :datatype_mismatch, code: :missing_field, expected_data_type: 'Positive Integer'),
                bad_request_error_pattern('responder_id', :datatype_mismatch, code: :missing_field, expected_data_type: 'Positive Integer'),
                bad_request_error_pattern('product_id', :datatype_mismatch, code: :missing_field, expected_data_type: 'Positive Integer'),
                bad_request_error_pattern('type', :not_included, code: :missing_field, list: ticket_type_list)])
    Helpdesk::TicketField.where(default: true).update_all(required: false)
    assert_response 400
    disable_skip_mandatory_checks_option
  end

   # test coverage for ticket creation without mandatory custom dropdown and non dropdown fields other than choices, dependent choices, section fields through public API without skip_mandatory_check enabled for current user having :admin_tasks privilege

  def test_create_ticket_without_mandatory_custom_text_without_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: "test_custom_text_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('custom_fields.test_custom_text', :datatype_mismatch, code: :missing_field, expected_data_type: 'String')])
    assert_response 400
    disable_adv_ticketing
    Helpdesk::TicketField.where(name: "test_custom_text_#{@account.id}").update_all(required: false)
  end

  def test_create_ticket_without_mandatory_custom_number_without_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: "test_custom_number_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('custom_fields.test_custom_number', :datatype_mismatch, code: :missing_field, expected_data_type: 'Integer')])
    assert_response 400
    disable_adv_ticketing
    Helpdesk::TicketField.where(name: "test_custom_number_#{@account.id}").update_all(required: false)
  end

  def test_create_ticket_without_mandatory_custom_checkbox_without_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: "test_custom_checkbox_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('custom_fields.test_custom_checkbox', :datatype_mismatch, code: :missing_field, expected_data_type: 'Boolean')])
    assert_response 400
    disable_adv_ticketing
    Helpdesk::TicketField.where(name: "test_custom_checkbox_#{@account.id}").update_all(required: false)
  end

  def test_create_ticket_without_mandatory_custom_date_without_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: "test_custom_date_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('custom_fields.test_custom_date', :invalid_date, code: :missing_field, accepted: 'yyyy-mm-dd')])
    assert_response 400
    disable_adv_ticketing
    Helpdesk::TicketField.where(name: "test_custom_date_#{@account.id}").update_all(required: false)
  end

  def test_create_ticket_without_mandatory_custom_paragraph_without_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: "test_custom_paragraph_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('custom_fields.test_custom_paragraph', :datatype_mismatch, code: :missing_field, expected_data_type: 'String')])
    assert_response 400
    disable_adv_ticketing
    Helpdesk::TicketField.where(name: "test_custom_paragraph_#{@account.id}").update_all(required: false)
  end

  def test_create_ticket_without_mandatory_custom_decimal_without_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: "test_custom_decimal_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('custom_fields.test_custom_decimal', :datatype_mismatch, code: :missing_field, expected_data_type: 'Number')])
    assert_response 400
    disable_adv_ticketing
    Helpdesk::TicketField.where(name: "test_custom_decimal_#{@account.id}").update_all(required: false)
  end

  def test_create_ticket_without_mandatory_custom_dropdown_field_withot_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: "test_custom_dropdown_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('custom_fields.test_custom_dropdown', :not_included, code: :missing_field, list: 'Get Smart,Pursuit of Happiness,Armaggedon')])
    assert_response 400
    disable_adv_ticketing
    Helpdesk::TicketField.where(name: "test_custom_dropdown_#{@account.id}").update_all(required: false)
  end

  def test_create_ticket_without_mandatory_custom_dropdown_and_non_dropdown_fields_without_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    @account.account_additional_settings.additional_settings[:skip_mandatory_checks] = false
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
    post :create, construct_params({}, params)
    pattern = []
    VALIDATABLE_CUSTOM_FIELDS.each do |custom_field|
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
    assert_response 400
    disable_adv_ticketing
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
  end

   # test coverage for ticket update without default mandatory fields with skip_mandatory_checks enabled for current user having :admin_tasks privilege thorough public API only

  def test_update_ticket_type_without_mandatory_default_fields_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = { email: Faker::Internet.email, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    Helpdesk::TicketField.where(default: true).update_all(required: true)
    t = create_ticket(params)
    t.ticket_type = nil
    t.save
    update_params = { type: 'Question' }
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    put :update, construct_params({ id: t.display_id }, update_params)
    t = @account.tickets.find(t.id)
    Helpdesk::TicketField.where(default: true).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    result = parse_response(@response.body)
    assert_equal t.ticket_type, 'Question'
    assert_equal result['nr_due_by'], nil
    assert_equal result['nr_escalated'], false
    disable_skip_mandatory_checks_option
  ensure
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_update_ticket_agent_without_mandatory_fields_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = { email: Faker::Internet.email, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    Helpdesk::TicketField.where(default: true).update_all(required: true)
    t = create_ticket(params)
    responder_id = add_test_agent(@account).id
    update_params = { responder_id: responder_id }
    put :update, construct_params({ id: t.display_id }, update_params)
    t = @account.tickets.find(t.id)
    Helpdesk::TicketField.where(default: true).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.agent.id, responder_id
    disable_skip_mandatory_checks_option
  end

  def test_update_ticket_product_without_mandatory_fields_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = { email: Faker::Internet.email, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    Helpdesk::TicketField.where(default: true).update_all(required: true)
    t = create_ticket(params)
    product = create_product
    update_params = { product_id: product.id }
    put :update, construct_params({ id: t.display_id }, update_params)
    t = @account.tickets.find(t.id)
    Helpdesk::TicketField.where(default: true).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.product.id, product.id
    disable_skip_mandatory_checks_option
  end

  def test_update_ticket_group_without_mandatory_fields_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = { email: Faker::Internet.email, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    Helpdesk::TicketField.where(default: true).update_all(required: true)
    t = create_ticket(params)
    group = create_group(@account)
    update_params = { group_id: group.id }
    put :update, construct_params({ id: t.display_id }, update_params)
    t = @account.tickets.find(t.id)
    Helpdesk::TicketField.where(default: true).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.group.id, group.id
    disable_skip_mandatory_checks_option
  end

  def test_update_ticket_status_without_mandatory_default_fields_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = { email: Faker::Internet.email, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    Helpdesk::TicketField.where(default: true).update_all(required: true)
    t = create_ticket(params)
    update_params = { status: 3 }
    put :update, construct_params({ id: t.display_id }, update_params)
    t = @account.tickets.find(t.id)
    Helpdesk::TicketField.where(default: true).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.status, 3
    disable_skip_mandatory_checks_option
  end

  def test_update_ticket_priority_without_mandatory_default_fields_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = { email: Faker::Internet.email, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    Helpdesk::TicketField.where(default: true).update_all(required: true)
    t = create_ticket(params)
    update_params = { priority: 3 }
    put :update, construct_params({ id: t.display_id }, update_params)
    t = @account.tickets.find(t.id)
    Helpdesk::TicketField.where(default: true).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.priority, 3
    disable_skip_mandatory_checks_option
  end

  def test_update_ticket_description_without_mandatory_default_fields_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = { email: Faker::Internet.email, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    Helpdesk::TicketField.where(default: true).update_all(required: true)
    t = create_ticket(params)
    update_params = { description: 'updated the description' }
    put :update, construct_params({ id: t.display_id }, update_params)
    t = @account.tickets.find(t.id)
    Helpdesk::TicketField.where(default: true).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.description, 'updated the description'
    disable_skip_mandatory_checks_option
  end

  def test_update_ticket_subject_without_mandatory_default_fields_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = { email: Faker::Internet.email, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    Helpdesk::TicketField.where(default: true).update_all(required: true)
    t = create_ticket(params)
    update_params = { subject: 'updated the subject' }
    put :update, construct_params({ id: t.display_id }, update_params)
    t = @account.tickets.find(t.id)
    Helpdesk::TicketField.where(default: true).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.subject, 'updated the subject'
    disable_skip_mandatory_checks_option
  end

   # test coverage for ticket update without mandatory custom fields with skip_mandatory_checks enabled for current user having :admin_tasks privilege thorough public API only

  def test_update_ticket_without_mandatory_custom_dropdown_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash.merge(custom_fields: {})
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
    t = create_ticket(params)
    update_params = { custom_fields: { test_custom_dropdown: 'Armaggedon' } }
    put :update, construct_params({ id: t.display_id }, update_params)
    t = @account.tickets.find(t.id)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.custom_field["test_custom_dropdown_#{@account.id}"], 'Armaggedon'
    disable_adv_ticketing
  end

  def test_update_ticket_without_mandatory_custom_text_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
    t = create_ticket(params)
    update_params = { custom_fields: { test_custom_text: 'updated text' } }
    put :update, construct_params({ id: t.display_id }, update_params)
    t = @account.tickets.find(t.id)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.custom_field["test_custom_text_#{@account.id}"], 'updated text'
    disable_adv_ticketing
  end

  def test_update_ticket_without_mandatory_custom_number_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
    t = create_ticket(params)
    update_params = { custom_fields: { test_custom_number: 4 } }
    put :update, construct_params({ id: t.display_id }, update_params)
    t = @account.tickets.find(t.id)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.custom_field["test_custom_number_#{@account.id}"], 4
    disable_adv_ticketing
  end

  def test_update_ticket_without_mandatory_custom_checkbox_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
    t = create_ticket(params)
    update_params = { custom_fields: { test_custom_checkbox: true } }
    put :update, construct_params({ id: t.display_id }, update_params)
    t = @account.tickets.find(t.id)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.custom_field["test_custom_checkbox_#{@account.id}"], true
    disable_adv_ticketing
  end

  def test_update_ticket_without_mandatory_custom_date_with_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
    t = create_ticket(params)
    update_params = { custom_fields: { test_custom_date: '2019-03-07' } }
    put :update, construct_params({ id: t.display_id }, update_params)
    t = @account.tickets.find(t.id)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.custom_field["test_custom_date_#{@account.id}"], '2019-03-07'
    disable_adv_ticketing
  end

  def test_update_ticket_without_mandatory_custom_paragraph_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
    t = create_ticket(params)
    update_params = { custom_fields: { test_custom_paragraph: 'updated paragraph' } }
    put :update, construct_params({ id: t.display_id }, update_params)
    t = @account.tickets.find(t.id)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.custom_field["test_custom_paragraph_#{@account.id}"], 'updated paragraph'
    disable_adv_ticketing
  end

  def test_update_ticket_without_mandatory_custom_decimal_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
    t = create_ticket(params)
    update_params = { custom_fields: { test_custom_decimal: 0.23 } }
    put :update, construct_params({ id: t.display_id }, update_params)
    t = @account.tickets.find(t.id)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.custom_field["test_custom_decimal_#{@account.id}"], 0.23
    disable_adv_ticketing
  end

  def test_update_ticket_without_mandatory_defalut_fields_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = { email: Faker::Internet.email, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    Helpdesk::TicketField.where(default: true).update_all(required: true)
    t = create_ticket(params)
    t = @account.tickets.find(t.id)
    update_params = { status: 3, type: 'Refund' }
    put :update, construct_params({ id: t.display_id }, update_params)
    t.reload
    Helpdesk::TicketField.where(default: true).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.status, 3
    assert_equal t.ticket_type, 'Refund'
    disable_adv_ticketing
  end

  def test_update_ticket_without_mandatory_custom_fields_with_skip_mandatory_checks_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
    t = create_ticket(params)
    update_params = { custom_fields: { test_custom_decimal: 0.23, test_custom_dropdown: 'Armaggedon' } }
    put :update, construct_params({ id: t.display_id }, update_params)
    t = @account.tickets.find(t.id)
    Helpdesk::TicketField.where(default: true).update_all(required: true)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.custom_field["test_custom_decimal_#{@account.id}"], 0.23
    assert_equal t.custom_field["test_custom_dropdown_#{@account.id}"], 'Armaggedon'
    disable_adv_ticketing
  end

  def test_update_ecommerce_ticket_using_public_api
    ticket = create_ebay_ticket
    update_params = { priority: 2, status: 3 }
    put :update, construct_params({ id: ticket.display_id }, update_params)
    assert_response 200
  end

   # test update ticket without mandatory default fields that are required for closure with skip_mandatory_checks enabled for current user having :admin_tasks privilege thorough public API only

  def test_reslove_ticket_without_type_with_required_for_closure_default_fields_withotut_skip_mandatory_skips_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash.except(:type)
    Helpdesk::TicketField.where(name: "ticket_type").update_all(required_for_closure: true)
    t = create_ticket(params)
    t.ticket_type = nil
    t.save
    update_params = { status: 4 }
    put :update, construct_params({ id: t.display_id }, update_params)
    Helpdesk::TicketField.where(name: 'ticket_type').update_all(required_for_closure: false)
    assert_response 400
    match_json([bad_request_error_pattern('type', :not_included, code: :missing_field, list: ticket_type_list)])
    disable_skip_mandatory_checks_option
  end

  def test_reslove_ticket_without_required_for_closure_default_fields_without_skip_mandatory_skips_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash.except(:product_id, :responder_id)
    Helpdesk::TicketField.where(name: ['product', 'agent']).update_all(required_for_closure: true)
    t = create_ticket(params)
    update_params = { status: 4 }
    put :update, construct_params({ id: t.display_id }, update_params)
    Helpdesk::TicketField.where(name: ['product', 'agent']).update_all(required_for_closure: false)
    assert_response 400
    match_json([bad_request_error_pattern('responder_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'Null'),
                bad_request_error_pattern('product_id', :datatype_mismatch, code: :missing_field, expected_data_type: 'Positive Integer')])
    disable_skip_mandatory_checks_option
  end

  def test_resolve_ticket_with_custom_text_with_required_for_closure_without_skip_mandatory_skips_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: "test_custom_text_#{@account.id}").update_all(required_for_closure: true)
    t = create_ticket(params)
    update_params = { status: 4 }
    put :update, construct_params({ id: t.display_id }, update_params)
    Helpdesk::TicketField.where(name: "test_custom_text_#{@account.id}").update_all(required_for_closure: false)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_text'), *(ERROR_REQUIRED_PARAMS['text']))])
    disable_skip_mandatory_checks_option
  end

  def test_resolve_ticket_without_required_for_closure_custom_fields_without_skip_mandatory_skips_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: ["test_custom_number_#{@account.id}", "test_custom_date_#{@account.id}"]).update_all(required_for_closure: true)
    t = create_ticket(params)
    update_params = { status: 4 }
    put :update, construct_params({ id: t.display_id }, update_params)
    Helpdesk::TicketField.where(name: ["test_custom_number_#{@account.id}", "test_custom_date_#{@account.id}"]).update_all(required_for_closure: false)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_number'), *(ERROR_REQUIRED_PARAMS['number'])),
                bad_request_error_pattern(custom_field_error_label('test_custom_date'), *(ERROR_REQUIRED_PARAMS['date']))])
    disable_skip_mandatory_checks_option
  end

  def test_close_ticket_without_type_with_required_for_closure_without_skip_mandatory_skips_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash.except(:type)
    Helpdesk::TicketField.where(name: "ticket_type").update_all(required_for_closure: true)
    t = create_ticket(params)
    t.ticket_type = nil
    t.save
    update_params = { status: 5 }
    put :update, construct_params({ id: t.display_id }, update_params)
    Helpdesk::TicketField.where(name: 'ticket_type').update_all(required_for_closure: false)
    assert_response 400
    match_json([bad_request_error_pattern('type', :not_included, code: :missing_field, list: ticket_type_list)])
    disable_skip_mandatory_checks_option
  end

  def test_close_ticket_without_required_for_closure_default_fields_without_skip_mandatory_skips_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash.except(:product_id, :responder_id)
    Helpdesk::TicketField.where(name: ['product', 'agent']).update_all(required_for_closure: true)
    t = create_ticket(params)
    update_params = { status: 5 }
    put :update, construct_params({ id: t.display_id }, update_params)
    Helpdesk::TicketField.where(name: ['product', 'agent']).update_all(required_for_closure: false)
    assert_response 400
    match_json([bad_request_error_pattern('responder_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'Null'),
                bad_request_error_pattern('product_id', :datatype_mismatch, code: :missing_field, expected_data_type: 'Positive Integer')])
    disable_skip_mandatory_checks_option
  end

  def test_close_ticket_with_custom_text_with_required_for_closure_without_skip_mandatory_skips_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: "test_custom_text_#{@account.id}").update_all(required_for_closure: true)
    t = create_ticket(params)
    update_params = { status: 5 }
    put :update, construct_params({ id: t.display_id }, update_params)
    Helpdesk::TicketField.where(name: "test_custom_text_#{@account.id}").update_all(required_for_closure: false)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_text'), *(ERROR_REQUIRED_PARAMS['text']))])
    disable_skip_mandatory_checks_option
  end

  def test_close_ticket_without_required_for_closure_custom_fields_without_skip_mandatory_skips_enabled
    enable_skip_mandatory_checks_option
    params = ticket_params_hash
    Helpdesk::TicketField.where(name: ["test_custom_number_#{@account.id}", "test_custom_date_#{@account.id}"]).update_all(required_for_closure: true)
    t = create_ticket(params)
    update_params = { status: 5 }
    put :update, construct_params({ id: t.display_id }, update_params)
    Helpdesk::TicketField.where(name: ["test_custom_number_#{@account.id}", "test_custom_date_#{@account.id}"]).update_all(required_for_closure: false)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_number'), *(ERROR_REQUIRED_PARAMS['number'])),
                bad_request_error_pattern(custom_field_error_label('test_custom_date'), *(ERROR_REQUIRED_PARAMS['date']))])
    disable_skip_mandatory_checks_option
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
    match_json([bad_request_error_pattern('email_config_id', :absent_in_db, resource: :email_config, attribute: :email_config_id)])
    assert_response 400
  end

  def test_update_with_invalid_email_config_id
    email_config = EmailConfig.first || create_email_config
    email_config.update_column(:account_id, 999)
    params = { email_config_id: email_config.reload.id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params)
    email_config.update_column(:account_id, @account.id)
    match_json([bad_request_error_pattern('email_config_id', :absent_in_db, resource: :email_config, attribute: :email_config_id)])
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

  def test_create_service_task_ticket
    enable_adv_ticketing([:field_service_management]) do
      begin   
        perform_fsm_operations
        Account.stubs(:current).returns(Account.first)
        parent_ticket = create_ticket
        params = { parent_id: parent_ticket.display_id, email: Faker::Internet.email,
                   description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                   priority: 2, status: 2, type: SERVICE_TASK_TYPE, 
                   custom_fields: { cf_fsm_contact_name: "test", cf_fsm_service_location: "test", cf_fsm_phone_number: "test" } }      
        post :create, construct_params(params)
        assert_response 201
      ensure
        cleanup_fsm
        Account.unstub(:current)
      end
    end
  end

  def test_create_service_task_ticket_failure
    enable_adv_ticketing([:field_service_management]) do
      begin
        perform_fsm_operations
        Account.stubs(:current).returns(Account.first)
        params = { email: Faker::Internet.email,
                 description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                 priority: 2, status: 2, type: SERVICE_TASK_TYPE, 
                 custom_fields: { cf_fsm_contact_name:
                  "test", cf_fsm_service_location: "test", cf_fsm_phone_number: "test" } }  
        post :create, construct_params({}, params)
        match_json([bad_request_error_pattern('ticket_type', :should_be_child, :type => SERVICE_TASK_TYPE, :code => :invalid_value)])
        assert_response 400
      ensure
        cleanup_fsm
        Account.unstub(:current)
      end 
    end
  end
  
  def test_create_service_task_ticket_with_support_agent
   enable_adv_ticketing([:field_service_management]) do
     begin
       perform_fsm_operations
       Account.stubs(:current).returns(Account.first)
       parent_ticket = create_ticket
       params = { responder_id: @agent.id, parent_id: parent_ticket.display_id, email: Faker::Internet.email,
                 description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                 priority: 2, status: 2, type: SERVICE_TASK_TYPE, 
                 custom_fields: { cf_fsm_contact_name: "test", cf_fsm_service_location: "test", cf_fsm_phone_number: "test" } }      
       post :create, construct_params(params)
       assert_response 201
     ensure
      cleanup_fsm
      Account.unstub(:current)
     end
   end
  end

  def test_create_non_service_task_ticket_with_invalid_field_agent_failure
    enable_adv_ticketing([:field_service_management]) do
      begin 
        perform_fsm_operations
        Account.stubs(:current).returns(Account.first)
        field_agent = create_field_agent
        params = { responder_id: field_agent.id, email: Faker::Internet.email,
                   description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                   priority: 2, status: 2 }
        post :create, construct_params(params)
        match_json([bad_request_error_pattern('responder_id', :field_agent_not_allowed, :code => :invalid_value)])
        assert_response 400
      ensure
        cleanup_fsm
        Account.unstub(:current)
      end
    end
  end

  def test_create_service_task_ticket_with_invalid_field_group_failure
    enable_adv_ticketing([:field_service_management]) do
      begin 
        perform_fsm_operations
        Account.stubs(:current).returns(Account.first)
        group = create_group(@account)    
        parent_ticket = create_ticket
        params = { group_id: group.id, parent_id: parent_ticket.display_id, email: Faker::Internet.email,
                   description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                   priority: 2, status: 2, type: SERVICE_TASK_TYPE, 
                   custom_fields: { cf_fsm_contact_name: "test", cf_fsm_service_location: "test", cf_fsm_phone_number: "test" } }      
        post :create, construct_params(params)
        match_json([bad_request_error_pattern('group_id', :only_field_group_allowed, :code => :invalid_value)])
        assert_response 400
      ensure
        cleanup_fsm
        Account.unstub(:current)

      end
    end
  end

  def test_create_non_service_task_ticket_with_invalid_field_group_failure
    enable_adv_ticketing([:field_service_management]) do
      begin 
        perform_fsm_operations
        Account.stubs(:current).returns(Account.first)
        field_group = create_field_agent_group
        params = { group_id: field_group.id, email: Faker::Internet.email,
                   description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                   priority: 2, status: 2 }
        post :create, construct_params(params)
        match_json([bad_request_error_pattern('group_id', :field_group_not_allowed, :code => :invalid_value)])
        assert_response 400
      ensure
        cleanup_fsm
        Account.unstub(:current)
      end
    end
  end

  def test_create_non_service_task_ticket_with_invalid_field_agent_and_group_failure
    enable_adv_ticketing([:field_service_management]) do
      begin 
        perform_fsm_operations
        Account.stubs(:current).returns(Account.first)
        field_group = create_field_agent_group
        field_agent = create_field_agent
        field_group.agent_groups.create(user_id: field_agent.id, group_id: field_agent.id)
        params = { group_id: field_group.id, responder_id: field_agent.id,  email: Faker::Internet.email,
                   description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                   priority: 2, status: 2 }
        post :create, construct_params(params)
        match_json([bad_request_error_pattern('group_id', :field_group_not_allowed, :code => :invalid_value),
                    bad_request_error_pattern('responder_id', :field_agent_not_allowed, :code => :invalid_value)])
        assert_response 400
      ensure
        cleanup_fsm
        Account.unstub(:current)
      end
    end
  end

  def test_update_service_task_ticket_type_failure
    enable_adv_ticketing([:field_service_management]) do
      begin
        perform_fsm_operations      
        fsm_ticket = create_service_task_ticket
        params = {:type => "Question"}
        put :update, construct_params({ id: fsm_ticket.display_id }, params)
        match_json([bad_request_error_pattern('ticket_type', :from_service_task_not_possible, :code => :invalid_value)])
        assert_response 400
      ensure
        cleanup_fsm
      end
    end
  end

  def test_update_non_service_task_ticket_to_service_task_failure
    enable_adv_ticketing([:field_service_management]) do
      begin
        perform_fsm_operations
        Account.stubs(:current).returns(Account.first)      
        ticket = create_ticket
        params = {:type => SERVICE_TASK_TYPE, custom_fields: { cf_fsm_contact_name: "test", cf_fsm_service_location: "test", cf_fsm_phone_number: "test" } }
        put :update, construct_params({ id: ticket.display_id }, params)
        match_json([bad_request_error_pattern('ticket_type', :to_service_task_not_possible, :code => :invalid_value)])
        assert_response 400
      ensure
        cleanup_fsm
        Account.unstub(:current)
      end
    end
  end

  def test_create_service_task_ticket
    enable_adv_ticketing([:field_service_management]) do
      begin
        cleanup_fsm
        perform_fsm_operations
        Account.stubs(:current).returns(Account.first)
        parent_ticket = create_ticket
        params = { parent_id: parent_ticket.display_id, email: Faker::Internet.email,
                   description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                   priority: 2, status: 2, type: SERVICE_TASK_TYPE, 
                   custom_fields: { cf_fsm_contact_name: "test", cf_fsm_service_location: "test", cf_fsm_phone_number: "test" } }      
        post :create, construct_params(params)
        assert_response 201
      ensure
        cleanup_fsm
        Account.unstub(:current)
      end
    end
  end

  def test_create_with_service_task_with_pc_disabled
    disable_adv_ticketing([:parent_child_tickets])
    enable_adv_ticketing([:field_service_management]) do
      begin
        cleanup_fsm  
        perform_fsm_operations
        Account.stubs(:current).returns(Account.first)
        parent_ticket = create_ticket
        params = { parent_id: parent_ticket.display_id, email: Faker::Internet.email,
                   description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                   priority: 2, status: 2, type: SERVICE_TASK_TYPE, 
                   custom_fields: { cf_fsm_contact_name: "test", cf_fsm_service_location: "test", cf_fsm_phone_number: "test" } }      
        post :create, construct_params(params)
        assert_response 201
      ensure
        cleanup_fsm
        Account.unstub(:current)
      end
    end
  end

  def test_create_with_service_task_with_both_advanced_features_disabled
    disable_adv_ticketing([:field_service_management, :parent_child_tickets])
    begin
      cleanup_fsm
      perform_fsm_operations
      Account.stubs(:current).returns(Account.first)
      parent_ticket = create_ticket
      params = { parent_id: parent_ticket.display_id, email: Faker::Internet.email,
                 description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
                 priority: 2, status: 2, type: SERVICE_TASK_TYPE, 
                 custom_fields: { cf_fsm_contact_name: "test", cf_fsm_service_location: "test", cf_fsm_phone_number: "test" } }      
      post :create, construct_params(params)
      assert_response 400
    ensure
      cleanup_fsm
      Account.unstub(:current)
    end
  end

  def test_create_with_tags_invalid
    params = { requester_id: requester.id, tags: ['test,,,,comma', 'test'], status: 2, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('tags', :special_chars_present, chars: ',')])
    assert_response 400
  end

  def test_create_duplicate_tags
    @account.tags.create(name: 'existing')
    @account.tags.create(name: 'TestCaps')
    params = { requester_id: requester.id, tags: ['new', '<1>new', 'existing', 'testcaps', '<2>existing', 'Existing', 'NEW'],
               status: 2, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph }
    assert_difference 'Helpdesk::Tag.count', 1 do # only new should be inserted.
      assert_difference 'Helpdesk::TagUse.count', 3 do # duplicates should be rejected
        post :create, construct_params({}, params)
      end
    end
    assert_response 201
    params[:tags] = %w(new existing TestCaps)
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
    match_json([bad_request_error_pattern('requester_id', :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: String, prepend_msg: :input_received),
                bad_request_error_pattern('responder_id', :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: String, prepend_msg: :input_received),
                bad_request_error_pattern('product_id', :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: String, prepend_msg: :input_received),
                bad_request_error_pattern('email_config_id', :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: String, prepend_msg: :input_received),
                bad_request_error_pattern('group_id', :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: String, prepend_msg: :input_received)])
    assert_response 400
  end

  def test_create_inclusion_invalid
    sources_list = @account.compose_email_enabled? ? '1,2,3,5,6,7,8,9,11,10' : '1,2,3,5,6,7,8,9,11'
    type_field_names = @account.ticket_fields.where(field_type: 'default_ticket_type').all.first.picklist_values.map(&:value).join(',')
    params = ticket_params_hash.merge(requester_id: requester.id, priority: 90, status: 56, type: 'jk', source: '89')
    post :create, construct_params({}, params)

    match_json([bad_request_error_pattern('priority', :not_included, list: '1,2,3,4'),
                bad_request_error_pattern('status', :not_included, list: '2,3,4,5,6,7'),
                bad_request_error_pattern('type', :not_included, list: ticket_type_list),
                bad_request_error_pattern('source', :not_included, list: sources_list)])
    assert_response 400
  end

  def test_create_inclusion_invalid_datatype
    sources_list = @account.compose_email_enabled? ? '1,2,3,5,6,7,8,9,11,10' : '1,2,3,5,6,7,8,9,11'
    params = ticket_params_hash.merge(requester_id: requester.id, priority: '1', status: '2', source: '9')
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('priority', :not_included, code: :datatype_mismatch, list: '1,2,3,4', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('status', :not_included, code: :datatype_mismatch, list: '2,3,4,5,6,7', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('source', :not_included, code: :datatype_mismatch, list: sources_list, prepend_msg: :input_received, given_data_type: String)])
    assert_response 400
  end

  def test_create_length_invalid
    params = ticket_params_hash.except(:email).merge(name: Faker::Lorem.characters(300), subject: Faker::Lorem.characters(300), phone: Faker::Lorem.characters(300), tags: [Faker::Lorem.characters(34)])
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('name', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('subject', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('phone', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('tags', :'It should only contain elements that have maximum of 32 characters')])
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
    match_json([bad_request_error_pattern('twitter_id', :'Has 300 characters, it can have maximum of 255 characters')])
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
    match_json([bad_request_error_pattern('email', :'Has 328 characters, it can have maximum of 255 characters')])
    assert_response 400
  end

  def test_create_invalid_email_with_dot
    Account.stubs(:current).returns(Account.first || create_test_account)
    Account.any_instance.stubs(:new_email_regex_enabled?).returns(true)
    params = ticket_params_hash.merge(email: 'test.@gmail.com')
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('email', :"It should be in the 'valid email address' format")])
    assert_response 400
  ensure
    Account.any_instance.unstub(:new_email_regex_enabled?)
    Account.unstub(:current)
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
    match_json([bad_request_error_pattern('name', :phone_mandatory, code: :missing_field)])
  end

  def test_create_email_format_invalid
    params = ticket_params_hash.merge(email: 'test@', cc_emails: ['the@'])
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('email', "It should be in the 'valid email address' format"),
                bad_request_error_pattern('cc_emails', "It should contain elements that are in the 'valid email address' format")])
  end

  def test_create_cc_email_format_invalid
    Account.stubs(:current).returns(Account.first || create_test_account)
    Account.any_instance.stubs(:new_email_regex_enabled?).returns(true)
    params = ticket_params_hash.merge(email: 'test@test.com', cc_emails: ['test.@test.com'])
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('cc_emails', "It should contain elements that are in the 'valid email address' format")])
  ensure
    Account.any_instance.unstub(:new_email_regex_enabled?)
    Account.unstub(:current)
  end

  def test_create_cc_email_format_valid
    params = ticket_params_hash.merge(email: 'test_1@test.com', cc_emails: ['test.2@test.com'])
    post :create, construct_params({}, params)
    assert_response 201
  end

  def test_create_data_type_invalid
    cc_emails = "#{Faker::Internet.email},#{Faker::Internet.email}"
    params = ticket_params_hash.merge(cc_emails: cc_emails, tags: 'tag1,tag2', custom_fields: [1])
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('cc_emails', :datatype_mismatch, expected_data_type: Array, given_data_type: String, prepend_msg: :input_received),
                bad_request_error_pattern('tags', :datatype_mismatch, expected_data_type: Array, given_data_type: String, prepend_msg: :input_received),
                bad_request_error_pattern('custom_fields', :datatype_mismatch, expected_data_type: 'key/value pair', given_data_type: Array, prepend_msg: :input_received)])
    assert_response 400
  end

  def test_create_date_time_invalid
    params = ticket_params_hash.merge(due_by: '7/7669/0', fr_due_by: '7/9889/0')
    post :create, construct_params({}, params)
    match_json([bad_request_error_pattern('due_by', :invalid_date, accepted: :'combined date and time ISO8601'),
                bad_request_error_pattern('fr_due_by', :invalid_date, accepted: :'combined date and time ISO8601')])
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
    match_json([bad_request_error_pattern('fr_due_by', :fr_due_by_validation, code: :missing_field)])
  end

  def test_create_with_nil_due_by_with_fr_due_by
    params = ticket_params_hash.merge(due_by: nil, fr_due_by: 12.days.since.iso8601)
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :due_by_validation, code: :missing_field)])
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
    match_json([bad_request_error_pattern('fr_due_by', :fr_due_by_validation, code: :missing_field)])
  end

  def test_create_without_due_by_with_fr_due_by
    params = ticket_params_hash.except(:due_by, :fr_due_by).merge(fr_due_by: 12.days.since.iso8601)
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :due_by_validation, code: :missing_field)])
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
    match_json([bad_request_error_pattern('cc_emails', :too_long, element_type: :values, max_count: "#{ApiTicketConstants::MAX_EMAIL_COUNT}", current_count: 50),
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
    match_json([bad_request_error_pattern('group_id', :absent_in_db, resource: :group, attribute: :group_id),
                bad_request_error_pattern('responder_id', :absent_in_db, resource: :agent, attribute: :responder_id),
                bad_request_error_pattern('email_config_id', :absent_in_db, resource: :email_config, attribute: :email_config_id),
                bad_request_error_pattern('product_id', :absent_in_db, resource: :product, attribute: :product_id),
                bad_request_error_pattern('requester_id', :user_blocked),
                bad_request_error_pattern(custom_field_error_label('test_custom_country'), :not_included, list: 'Australia,USA'),
                bad_request_error_pattern(custom_field_error_label('test_custom_dropdown'), :not_included, list:  'Get Smart,Pursuit of Happiness,Armaggedon')])
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
    match_json([bad_request_error_pattern('requester_id', :absent_in_db, attribute: :requester_id, resource: :contact)])
  end

  def test_create_extra_params_invalid
    params = ticket_params_hash.merge(junk: 'test', description_html: 'test')
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('junk', :invalid_field), bad_request_error_pattern('description_html', :invalid_field)])
  end

  def test_create_empty_params
    params = {}
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('requester_id', :fill_a_mandatory_field, field_names: 'requester_id, phone, email, twitter_id, facebook_id'),
                bad_request_error_pattern('subject', :datatype_mismatch, expected_data_type: String),
                bad_request_error_pattern('description', :datatype_mismatch, expected_data_type: String),
                bad_request_error_pattern('priority', :not_included, code: :missing_field, list: '1,2,3,4'),
                bad_request_error_pattern('status', :not_included, code: :missing_field, list: '2,3,4,5,6,7')])
  end

  def test_create_datatype_invalid
    post :create, construct_params({}, ticket_params_hash.merge(description: true))
    assert_response 400
    match_json([bad_request_error_pattern('description', :datatype_mismatch, expected_data_type: String, given_data_type: 'Boolean', prepend_msg: :input_received)])
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

  def test_create_without_value_for_boolean_custom_field
    post :create, construct_params({}, ticket_params_hash)
    assert_equal Helpdesk::Ticket.last.test_custom_checkbox_1, false
  end

  def test_create_with_value_for_boolean_custom_field_as_true
    params = ticket_params_hash.merge(custom_fields: {})
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({}, params)
    assert_equal Helpdesk::Ticket.last.test_custom_checkbox_1, true
  end

  def test_create_with_value_for_boolean_custom_field_as_false
    params = ticket_params_hash.merge(custom_fields: {})
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = UPDATE_CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({}, params)
    assert_equal Helpdesk::Ticket.last.test_custom_checkbox_1, false
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
    response_params = params.except(:tags, :attachments)
    match_json(ticket_pattern(params.merge(status: 2, priority: 2, source: 2), Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    assert_response 201
    assert Helpdesk::Ticket.last.attachments.count == 2
  ensure
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_create_with_invalid_attachment_array
    params = ticket_params_hash.merge('attachments' => [1, 2])
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_datatype_mismatch, expected_data_type: 'valid file format')])
  end

  def test_create_with_invalid_attachment_type
    params = ticket_params_hash.merge('attachments' => 'test')
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :datatype_mismatch, expected_data_type: Array, given_data_type: String, prepend_msg: :input_received)])
  end

  def test_create_with_invalid_empty_attachment
    params = ticket_params_hash.merge('attachments' => [])
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :blank)])
  end

  def test_attachment_invalid_size_create
    invalid_attachment_limit = @account.attachment_limit + 2
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(invalid_attachment_limit.megabytes)
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    params = ticket_params_hash.merge('attachments' => [file])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{invalid_attachment_limit} MB")])
  ensure
    Rack::Test::UploadedFile.any_instance.unstub(:size)
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_attachment_invalid_size_update
    attachment = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id)
    invalid_attachment_limit = @account.attachment_limit + 2
    Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(invalid_attachment_limit.megabytes)
    Helpdesk::Attachment.any_instance.stubs(:size).returns(invalid_attachment_limit.megabytes)
    params = update_ticket_params_hash.merge('attachments' => [attachment])
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    Helpdesk::Ticket.any_instance.stubs(:attachments).returns([attachment])
    ticket = create_ticket
    put :update, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{2 * invalid_attachment_limit} MB")])
  ensure
    DataTypeValidator.any_instance.unstub(:valid_type?)
    Helpdesk::Attachment.any_instance.unstub(:content_file_size)
    Helpdesk::Attachment.any_instance.unstub(:size)
    Helpdesk::Ticket.any_instance.unstub(:attachments)
  end

  def test_create_with_nested_custom_fields_with_invalid_first_children_valid
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'uyiyiuy', 'test_custom_state' => 'Queensland', 'test_custom_city' => 'Brisbane' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_country'), :not_included, list: 'Australia,USA')])
  end

  def test_create_with_nested_custom_fields_with_invalid_first_children_invalid
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'uyiyiuy', 'test_custom_state' => 'ss', 'test_custom_city' => 'ss' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_country'), :not_included, list: 'Australia,USA')])
  end

  def test_create_with_nested_custom_fields_with_valid_first_invalid_second_valid_third
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'hjhj', 'test_custom_city' => 'Brisbane' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_state'), :not_included, list: 'New South Wales,Queensland')])
  end

  def test_create_with_nested_custom_fields_with_valid_first_invalid_second_without_third
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'hjhj' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_state'), :not_included, list: 'New South Wales,Queensland')])
  end

  def test_create_with_nested_custom_fields_with_valid_first_invalid_second_without_third_invalid_third
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'hjhj', 'test_custom_city' => 'sfs' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_state'), :not_included, list: 'New South Wales,Queensland')])
  end

  def test_create_with_nested_custom_fields_without_first_with_second_and_third
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_state' => 'Queensland', 'test_custom_city' => 'Brisbane' })
    post :create, construct_params({}, params)
    assert_response 400
    assert_includes([
                        bad_request_error_pattern(custom_field_error_label('test_custom_country'), :conditional_not_blank, child: 'test_custom_state'),
                        bad_request_error_pattern(custom_field_error_label('test_custom_country'), :conditional_not_blank, child: 'test_custom_city')
                    ].map(&:with_indifferent_access),
                    JSON.parse(response.body)["errors"].first)
  end

  def test_create_with_nested_custom_fields_with_valid_first_valid_second_invalid_third
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'Queensland', 'test_custom_city' => 'ddd' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_city'), :not_included, list: 'Brisbane')])
  end

  def test_create_with_nested_custom_fields_with_valid_first_valid_second_invalid_other_third
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'Queensland', 'test_custom_city' => 'Sydney' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_city'), :not_included, list: 'Brisbane')])
  end


  def test_create_with_nested_custom_fields_without_first_with_second_only
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_state' => 'Queensland' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_country'), :conditional_not_blank, child: 'test_custom_state')])
  end

  def test_create_with_nested_custom_fields_without_first_with_third_only
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_city' => 'Brisbane' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_country'), :conditional_not_blank, child: 'test_custom_city'),
                bad_request_error_pattern(custom_field_error_label('test_custom_state'), :conditional_not_blank, child: 'test_custom_city')])
  end

  def test_create_with_nested_custom_fields_without_second_with_third
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_city' => 'Brisbane' })
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_state'), :conditional_not_blank, child: 'test_custom_city')])
  end

  def test_create_with_nested_custom_fields_required_without_second_level
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia' })
    ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
    ticket_field.update_attribute(:required, true)
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required, false)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_state'), :not_included, code: :missing_field, list: 'New South Wales,Queensland')])
  end

  def test_create_with_nested_custom_fields_required_without_third_level
    params = ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'Queensland' })
    ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
    ticket_field.update_attribute(:required, true)
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required, false)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_city'), :not_included, code: :missing_field, list: 'Brisbane')])
  end

  def test_create_with_nested_custom_fields_required_for_closure_without_second_level
    params = ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4, custom_fields: { 'test_custom_country' => 'Australia' })
    ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
    ticket_field.update_attribute(:required_for_closure, true)
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_state'), :not_included, code: :missing_field, list: 'New South Wales,Queensland')])
  end

  def test_create_with_nested_custom_fields_required_for_closure_without_third_level
    params = ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4, custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'Queensland' })
    ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
    ticket_field.update_attribute(:required_for_closure, true)
    post :create, construct_params({}, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_city'), :not_included, code: :missing_field, list: 'Brisbane')])
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
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_REQUIRED_PARAMS[custom_field]))
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
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_REQUIRED_PARAMS[custom_field]))
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
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_REQUIRED_PARAMS[custom_field]))
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
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_CHOICES_REQUIRED_PARAMS[custom_field]))
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
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_CHOICES_REQUIRED_PARAMS[custom_field]))
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
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_CHOICES_REQUIRED_PARAMS[custom_field]))
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
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_PARAMS[custom_field]))
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
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"),  *(ERROR_PARAMS[custom_field]))
    end
    match_json(pattern)
  end

  def test_update_with_custom_fields_required_for_closure_with_status_closed
    t = create_ticket
    params_hash = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 5)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required_for_closure: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required_for_closure: false)
    pattern = []
    (VALIDATABLE_CUSTOM_FIELDS - ['checkbox']).each do |custom_field|
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
    assert_response 400
  end

  def test_update_with_custom_fields_required_for_closure_with_status_resolved
    t = create_ticket
    params_hash = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required_for_closure: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required_for_closure: false)
    pattern = []
    (VALIDATABLE_CUSTOM_FIELDS - ['checkbox']).each do |custom_field|
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
    assert_response 400
  end

  def test_update_with_custom_fields_required
    params_hash = update_ticket_params_hash
    t = create_ticket
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
    assert_response 400
    pattern = []
    (VALIDATABLE_CUSTOM_FIELDS - ['checkbox']).each do |custom_field|
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
  end

  def test_update_with_custom_fields_required_with_checkbox_as_nil
    params_hash = update_ticket_params_hash
    t = create_ticket
    t.test_custom_checkbox_1 = nil
    t.save
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
    assert_response 400
    pattern = []
    (VALIDATABLE_CUSTOM_FIELDS).each do |custom_field|
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
  end

  def test_update_with_custom_fields_required_which_is_already_present
    params_hash = update_ticket_params_hash.except(:description)
    params = ticket_params_hash.except(:description).merge(custom_field: {})
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_field]["test_custom_#{custom_field}_#{@account.id}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    t = create_ticket(params)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: [@@custom_field_names]).update_all(required: false)
    match_json(update_ticket_pattern(params.merge(params_hash), t.reload))
    match_json(update_ticket_pattern({}, t))
    assert_response 200
  end

  def test_update_with_choices_custom_fields_required_for_closure_with_status_closed
    t = create_ticket(ticket_params_hash)
    params_hash = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 5)
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required_for_closure: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required_for_closure: false)
    pattern = []
    ['dropdown', 'country'].each do |custom_field|
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_CHOICES_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
    assert_response 400
  end

  def test_update_with_choices_custom_fields_required_for_closure_with_status_resolved
    t = create_ticket(ticket_params_hash)
    params_hash = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4)
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required_for_closure: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required_for_closure: false)
    pattern = []
    ['dropdown', 'country'].each do |custom_field|
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_CHOICES_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
    assert_response 400
  end

  def test_update_with_choices_custom_fields_required
    params_hash = update_ticket_params_hash
    t = create_ticket(ticket_params_hash)
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: [@@choices_custom_field_names]).update_all(required: false)
    assert_response 400
    pattern = []
    ['dropdown', 'country'].each do |custom_field|
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_CHOICES_REQUIRED_PARAMS[custom_field]))
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
    response_params = params.except(:tags, :attachments)
    match_json(update_ticket_pattern(params, t.reload))
    match_json(update_ticket_pattern({}, t))
    assert_response 200
    assert ticket.attachments.count == 2
  ensure
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_update_with_invalid_attachment_params_format
    params = update_ticket_params_hash.merge('attachments' => [1, 2])
    put :update, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('attachments', :array_datatype_mismatch, expected_data_type: 'valid file format')])
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
    match_json(update_ticket_pattern(params_hash, t.reload))
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_nil t.product_id
    portal.update_column(:product_id, nil)
  end

  def test_update_with_associated_company_deleted
    new_user = add_new_user(@account)
    company = Company.create(name: Faker::Name.name, account_id: @account.id)
    company.save
    new_user.user_companies.create(company_id: company.id, default: true)
    sample_requester = new_user.reload
    company_id = sample_requester.company_id
    ticket = create_ticket({ requester_id: sample_requester.id, company_id: company_id })
    @account.companies.find_by_id(company_id).destroy
    params_hash = { status: 5 }
    put :update, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 200
    match_json(update_ticket_pattern({}, ticket.reload))
    assert_equal 5, ticket.status
  end

  def test_update_requester_having_multiple_companies
    new_user = add_new_user(@account)
    company = Company.create(name: Faker::Name.name, account_id: @account.id)
    company.save
    new_user.user_companies.create(company_id: company.id, default: true)
    other_company = create_company
    new_user.user_companies.create(company_id: other_company.id)
    sample_requester = new_user.reload
    company_id = sample_requester.company_id
    ticket = create_ticket({ requester_id: sample_requester.id, company_id: company_id })
    @account.companies.find_by_id(company_id).destroy
    params_hash = { status: 5 }
    put :update, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 200
  end

  def test_update_company
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
    new_user = add_new_user(@account)
    company = Company.create(name: Faker::Name.name, account_id: @account.id)
    company.save
    new_user.user_companies.create(company_id: company.id, default: true)
    other_company = create_company
    new_user.user_companies.create(company_id: other_company.id)
    sample_requester = new_user.reload
    company_id = sample_requester.company_id
    ticket = create_ticket({ requester_id: sample_requester.id, company_id: company_id })
    params_hash = { status: 5, company_id: other_company.id }
    put :update, construct_params({ id: ticket.display_id }, params_hash)
    assert_response 200
    match_json(update_ticket_pattern({}, ticket.reload))
    assert_equal other_company.id, ticket.company_id
  ensure
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
  end

  def test_update_closed_with_nil_due_by_without_fr_due_by
    t = ticket
    params = update_ticket_params_hash.except(:fr_due_by).merge(status: 5, due_by: nil)
    put :update, construct_params({ id: t.display_id }, params)
    t = Helpdesk::Ticket.last
    match_json(update_ticket_pattern(params, t))
    match_json(update_ticket_pattern({}, t))
    assert_response 200
    t.update_column(:status, 2)
    assert_not_nil t.due_by && t.frDueBy
  end

  def test_update_with_nil_fr_due_by_without_due_by
    t = ticket
    params = update_ticket_params_hash.except(:due_by).merge(status: 5, fr_due_by: nil)
    put :update, construct_params({ id: t.display_id }, params)
    t = Helpdesk::Ticket.last
    match_json(update_ticket_pattern(params, t))
    match_json(update_ticket_pattern({}, t))
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
    match_json(update_ticket_pattern(params, t.reload))
    match_json(update_ticket_pattern({}, t))
    assert_response 200
    assert_equal fr_due_by.utc.iso8601, t.reload.frDueBy.iso8601
    assert_equal due_by, t.due_by.iso8601
  end

  def test_update_with_nil_due_by_with_fr_due_by
    t = ticket
    fr_due_by = 2.days.since.utc.iso8601
    params = update_ticket_params_hash.merge(due_by: nil, fr_due_by: fr_due_by)
    put :update, construct_params({ id: t.display_id }, params)
    match_json(update_ticket_pattern(params, t.reload))
    match_json(update_ticket_pattern({}, t))
    assert_response 200
    t.update_column(:status, 2)
    assert_not_nil t.reload.due_by
    assert_equal fr_due_by, t.frDueBy.iso8601
  end

  def test_update_closed_with_nil_due_by_fr_due_by
    t = ticket
    params = update_ticket_params_hash.merge(status: 5, due_by: nil, fr_due_by: nil)
    put :update, construct_params({ id: t.display_id }, params)
    match_json(update_ticket_pattern(params, t.reload))
    match_json(update_ticket_pattern({}, t))
    assert_response 200
    t.update_column(:status, 2)
    assert_not_nil t.due_by && t.frDueBy
  end

  def test_update_with_nil_due_by_fr_due_by
    t = ticket
    params = update_ticket_params_hash.merge(due_by: nil, fr_due_by: nil)
    put :update, construct_params({ id: t.display_id }, params)
    match_json(update_ticket_pattern(params, t.reload))
    match_json(update_ticket_pattern({}, t))
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
    put :update, construct_params({ id: t.display_id }, params)
    match_json([bad_request_error_pattern('fr_due_by', 'lt_due_by')])
    assert_response 400

    # fr_due_by in params
    t = ticket
    due_by = 30.days.since.utc.iso8601
    t.update_column(:due_by, due_by.to_datetime)
    fr_due_by = 31.days.since.utc.iso8601
    params = update_ticket_params_hash.except(:due_by).merge(fr_due_by: fr_due_by)
    put :update, construct_params({ id: t.display_id }, params)
    match_json([bad_request_error_pattern('fr_due_by', 'lt_due_by')])
    assert_response 400

    # due_by in params
    t = ticket
    due_by = 30.days.since.utc.iso8601
    fr_due_by = 31.days.since.utc.iso8601
    t.update_column(:frDueBy, fr_due_by.to_datetime)
    params = update_ticket_params_hash.except(:fr_due_by).merge(due_by: due_by)
    put :update, construct_params({ id: t.display_id }, params)
    match_json([bad_request_error_pattern('due_by', 'lt_due_by')])
    assert_response 400
  end

  def test_update_without_due_by
    params = update_ticket_params_hash
    t = ticket
    t.update_attribute(:due_by, (t.created_at - 10.days).iso8601)
    put :update, construct_params({ id: t.display_id }, params)
    match_json(update_ticket_pattern(params, t.reload))
    match_json(update_ticket_pattern({}, t))
    assert_response 200
  end

  def test_update_without_fr_due_by
    params = update_ticket_params_hash
    t = ticket
    t.update_attribute(:frDueBy, (t.created_at - 10.days).iso8601)
    put :update, construct_params({ id: t.display_id }, params)
    match_json(update_ticket_pattern(params, t.reload))
    match_json(update_ticket_pattern({}, t))
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
    match_json([bad_request_error_pattern('group_id', :absent_in_db, resource: :group, attribute: :group_id),
                bad_request_error_pattern('responder_id', :absent_in_db, resource: :agent, attribute: :responder_id),
                bad_request_error_pattern('email_config_id', :absent_in_db, resource: :email_config, attribute: :email_config_id),
                bad_request_error_pattern('requester_id', :user_blocked),
                bad_request_error_pattern('product_id', :absent_in_db, resource: :product, attribute: :product_id),
                bad_request_error_pattern(custom_field_error_label('test_custom_country'), :not_included, list: 'Australia,USA'),
                bad_request_error_pattern(custom_field_error_label('test_custom_dropdown'), :not_included, list:  'Get Smart,Pursuit of Happiness,Armaggedon')])
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
    match_json(update_ticket_pattern({}, t.reload))
  end

  def test_update_with_responder_id_not_in_group
    group = create_group(@account)
    params = { responder_id: @agent.id, group_id: group.id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params)
    match_json(update_ticket_pattern(params, t.reload))
    match_json(update_ticket_pattern({}, t))
    assert_response 200
  end

  def test_update_with_email_config_id
    email_config = create_email_config
    params_hash = { email_config_id: email_config.id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_equal t.reload.email_config_id, params_hash[:email_config_id]
    match_json(update_ticket_pattern({}, t))
    assert_response 200
  end

  def test_update_with_product_id
    product = create_product
    params_hash = { product_id: product.id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_equal t.reload.email_config_id, product.primary_email_config.id
    match_json(update_ticket_pattern({}, t))
    assert_response 200
  end

  def test_update_with_product_required_not_in_request_in_db
    params_hash = { priority: 1 }
    Helpdesk::TicketField.where(name: "product").update_all(required: true)
    product = create_product
    t = ticket
    t.schema_less_ticket.update_column(:product_id, product.id)
    put :update, construct_params({ id: t.display_id}, params_hash)
    Helpdesk::TicketField.where(name: "product").update_all(required: false)
    match_json(update_ticket_pattern({}, t.reload))
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
    match_json(update_ticket_pattern({}, t.reload))
  end

  def test_update_with_product_id_and_same_email_config_id
    product = create_product
    email_config = create_email_config(product_id: product.id)
    params_hash = { product_id: product.id, email_config_id: email_config.id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_equal t.reload.email_config_id, params_hash[:email_config_id]
    assert_equal t.product_id, params_hash[:product_id]
    match_json(update_ticket_pattern({}, t))
    assert_response 200
  end

  def test_update_with_low_priority
    params_hash = { priority: 1 }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert t.reload.priority == 1
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
  end

  def test_update_with_type
    params_hash = { type: 'Incident' }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(update_ticket_pattern({}, t.reload))
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
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
  end

  def test_update_with_description
    description =  Faker::Lorem.paragraph
    params_hash = { description: description }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert t.reload.description == description
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
  end

  def test_update_with_responder_id_in_group
    responder_id = add_test_agent(@account).id
    params_hash = { responder_id: responder_id }
    t = ticket
    group = t.group
    group.agent_groups.create(user_id: responder_id, group_id: group.id)
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert t.reload.responder_id == responder_id
  end

  def test_update_with_requester_id
    requester_id = add_new_user(@account).id
    params_hash = { requester_id: requester_id }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert t.reload.requester_id == requester_id
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
  end

  def test_update_with_group_id
    t = ticket
    group_id = create_group_with_agents(@account, agent_list: [t.responder_id]).id
    params_hash = { group_id: group_id }
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert t.reload.group_id == group_id
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
  end

  def test_update_with_source
    params_hash = { source: 2 }
    t = ticket
    t.send("test_custom_paragraph_#{@account.id}=", Faker::Lorem.characters(20))
    t.save
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert t.reload.source == 2
  end

  def test_update_with_source_as_bot
    params_hash = { source: Account.current.helpdesk_sources.ticket_source_keys_by_token[:bot] }
    put :update, construct_params({ id: ticket.display_id }, params_hash)
    match_json(update_ticket_pattern({}, ticket.reload))
    assert_response 200
    assert ticket.reload.source == 12
  end

  def test_update_with_tags
    tags = [Faker::Name.name, Faker::Name.name]
    params_hash = { tags: tags }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert t.reload.tag_names == tags
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
  end

  def test_update_with_closed_status
    params_hash = { status: 5 }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert t.reload.status == 5
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
  end

  def test_update_with_resolved_status
    params_hash = { status: 4 }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(update_ticket_pattern({}, t.reload))
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
    assert t.reload.requester_id == User.last.id
  end

  def test_update_with_new_twitter_id_without_nil_requester_id
    params_hash = update_ticket_params_hash.merge(twitter_id:  "@#{Faker::Name.name}")
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 200
    assert User.count == count + 1
    assert t.reload.requester_id == User.last.id
  end

  def test_update_with_new_phone_without_nil_requester_id
    params_hash = update_ticket_params_hash.merge(phone: Faker::PhoneNumber.phone_number, name:  Faker::Name.name)
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 200
    assert User.count == count + 1
    assert t.reload.requester_id == User.last.id
  end

  def test_update_with_new_email_with_nil_requester_id
    email = Faker::Internet.email
    params_hash = update_ticket_params_hash.merge(email: email, requester_id: nil)
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(update_ticket_pattern(params_hash, t.reload))
    match_json(update_ticket_pattern({}, t))
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
    match_json(update_ticket_pattern(params_hash, t.reload))
    match_json(update_ticket_pattern({}, t))
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
    match_json(update_ticket_pattern(params_hash, t.reload))
    match_json(update_ticket_pattern({}, t))
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
    match_json(update_ticket_pattern(params_hash, t.reload))
    match_json(update_ticket_pattern({}, t))
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
    match_json(update_ticket_pattern(params_hash, t.reload))
    match_json(update_ticket_pattern({}, t))
    assert_response 200
    assert t.reload.due_by != previous_due_by
  end

  def test_update_with_fr_due_by
    t = create_ticket(ticket_params_hash.except(:fr_due_by, :due_by))
    previous_fr_due_by = t.frDueBy
    params_hash = { fr_due_by: 2.hours.since.iso8601 }
    Helpdesk::Ticket.any_instance.expects(:update_dueby).never
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(update_ticket_pattern(params_hash, t.reload))
    match_json(update_ticket_pattern({}, t))
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
    params_hash = { status: 4, due_by: time, custom_fields: {
        test_custom_paragraph: Faker::Lorem.characters(200)
    } }
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :cannot_set_due_by_fields, code: :incompatible_field)])
  end

  def test_update_with_status_closed_and_only_fr_due_by
    t = ticket
    t.send("test_custom_paragraph_#{@account.id}=", Faker::Lorem.characters(20))
    t.save
    time = 4.days.since.iso8601
    params_hash = { status: 5, fr_due_by: time }
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('fr_due_by', :cannot_set_due_by_fields, code: :incompatible_field)])
  end

  def test_update_with_status_closed_and_due_by
    t = ticket
    t.send("test_custom_paragraph_#{@account.id}=", Faker::Lorem.characters(20))
    t.save
    time1 = 12.days.since.iso8601
    time2 = 4.days.since.iso8601
    params_hash = { status: 5, due_by: time1, fr_due_by: time2 }
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :cannot_set_due_by_fields, code: :incompatible_field),
                bad_request_error_pattern('fr_due_by', :cannot_set_due_by_fields, code: :incompatible_field)])
  end

  def test_update_with_sla_timer_off_status_and_only_fr_due_by
    t = ticket
    time = 4.days.since.iso8601
    status = create_custom_status
    params_hash = { status: status.status_id, fr_due_by: time }
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('fr_due_by', :cannot_set_due_by_fields, code: :incompatible_field)])
  ensure
    status.destroy
  end

  def test_update_with_sla_timer_off_status_and_due_by
    t = ticket
    time1 = 12.days.since.iso8601
    time2 = 4.days.since.iso8601
    status = create_custom_status
    params_hash = { status: status.status_id, due_by: time1, fr_due_by: time2 }
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :cannot_set_due_by_fields, code: :incompatible_field),
                bad_request_error_pattern('fr_due_by', :cannot_set_due_by_fields, code: :incompatible_field)])
  ensure
    status.destroy
  end

  def test_update_numericality_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: 'yu', responder_id: 'io', product_id: 'x', email_config_id: 'x', group_id: 'g')
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('requester_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('responder_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('product_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('email_config_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('group_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)])
  end

  def test_update_inclusion_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: requester.id, priority: 90, status: 56, type: 'jk', source: '89')
    type_field_names = Account.current.ticket_type_values.map(&:value).join(',')
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('priority', :not_included, list: '1,2,3,4'),
                bad_request_error_pattern('status', :not_included, list: '2,3,4,5,6,7'),
                bad_request_error_pattern('type', :not_included, list: ticket_type_list),
                bad_request_error_pattern('source', :not_included, list: '1,2,3,5,6,7,8,9,11,10,12')])
  end

  def test_update_length_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(name: Faker::Lorem.characters(300), requester_id: nil, subject: Faker::Lorem.characters(300), phone: Faker::Lorem.characters(300), tags: [Faker::Lorem.characters(34)])
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json([bad_request_error_pattern('name', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('subject', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('phone', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('tags', :'It should only contain elements that have maximum of 32 characters')])
    assert_response 400
  end

  def test_update_length_valid_with_trailing_spaces
    t = ticket
    params_hash = update_ticket_params_hash.merge(custom_fields: { 'test_custom_text' => Faker::Lorem.characters(20) + white_space }, name: Faker::Lorem.characters(20) + white_space, requester_id: nil, subject: Faker::Lorem.characters(20) + white_space, phone: Faker::Lorem.characters(20) + white_space, tags: [Faker::Lorem.characters(20) + white_space])
    put :update, construct_params({ id: t.display_id }, params_hash)
    params_hash[:tags].each(&:strip!)
    result = params_hash.each { |x, y| y.strip! if [:name, :subject, :phone].include?(x) }
    match_json(update_ticket_pattern(params_hash, t.reload))
    match_json(update_ticket_pattern({}, t))
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
    match_json([bad_request_error_pattern('twitter_id', :'Has 300 characters, it can have maximum of 255 characters')])
    assert_response 400
  end

  def test_update_length_valid_twitter_id_with_trailing_space
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: nil, twitter_id: Faker::Lorem.characters(20) + white_space)
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(update_ticket_pattern(params_hash, t.reload))
    match_json(update_ticket_pattern({}, t))
    assert_response 200
    assert_equal t.reload.requester.twitter_id, params_hash[:twitter_id].strip
    match_json(ticket_pattern({}, t.reload))
  end

  def test_update_length_invalid_email
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: nil, email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(300)}.com")
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json([bad_request_error_pattern('email', :'Has 328 characters, it can have maximum of 255 characters')])
    assert_response 400
  end

  def test_update_length_valid_email_with_trailing_space
    t = ticket
    params_hash = update_ticket_params_hash.merge(requester_id: nil, email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(20)}.com" + white_space)
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(update_ticket_pattern(params_hash, t.reload))
    match_json(update_ticket_pattern({}, t))
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
    match_json([bad_request_error_pattern('name', :phone_mandatory, code: :missing_field)])
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
    match_json([bad_request_error_pattern('tags', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern('custom_fields', :datatype_mismatch, expected_data_type: 'key/value pair', prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_update_date_time_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(due_by: '7/7669/0', fr_due_by: '7/9889/0')
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('due_by', :invalid_date, accepted: :'combined date and time ISO8601'),
                bad_request_error_pattern('fr_due_by', :invalid_date, accepted: :'combined date and time ISO8601')])
  end

  def test_update_extra_params_invalid
    t = ticket
    params_hash = update_ticket_params_hash.merge(junk: 'test', description_html: 'test')
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('junk', :invalid_field), bad_request_error_pattern('description_html', :invalid_field)])
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
    match_json(update_ticket_pattern(params_hash, t.reload))
    match_json(update_ticket_pattern({}, t))
    assert_response 200
    assert User.count == count
  end

  def test_update_with_existing_twitter
    user = add_new_user_with_twitter_id(@account)
    params_hash = update_ticket_params_hash.except(:email).merge(twitter_id: user.twitter_id, requester_id: nil)
    count = User.count
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(update_ticket_pattern(params_hash, t.reload))
    match_json(update_ticket_pattern({}, t))
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
    match_json(update_ticket_pattern(params_hash, t.reload))
    match_json(update_ticket_pattern({}, t))
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
    match_json(update_ticket_pattern(params_hash, t.reload))
    match_json(update_ticket_pattern({}, t))
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
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_country'), :not_included, list: 'Australia,USA')])
  end

  def test_update_with_nested_custom_fields_with_invalid_first_children_invalid
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'uyiyiuy', 'test_custom_state' => 'ss', 'test_custom_city' => 'ss' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_country'), :not_included, list: 'Australia,USA')])
  end

  def test_update_with_nested_custom_fields_with_valid_first_invalid_second_valid_third
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'hjhj', 'test_custom_city' => 'Brisbane' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_state'), :not_included, list: 'New South Wales,Queensland')])
  end

  def test_update_with_nested_custom_fields_with_valid_first_invalid_second_without_third
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'hjhj' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_state'), :not_included, list: 'New South Wales,Queensland')])
  end

  def test_update_with_nested_custom_fields_with_valid_first_invalid_second_without_third_invalid_third
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'hjhj', 'test_custom_city' => 'sfs' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_state'), :not_included, list: 'New South Wales,Queensland')])
  end

  def test_update_with_nested_custom_fields_with_valid_first_valid_second_invalid_third
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'Queensland', 'test_custom_city' => 'ddd' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_city'), :not_included, list: 'Brisbane')])
  end

  def test_update_with_nested_custom_fields_with_valid_first_valid_second_invalid_other_third
    t = ticket
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'Queensland', 'test_custom_city' => 'Sydney' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_city'), :not_included, list: 'Brisbane')])
  end

  def test_update_with_nested_custom_fields_without_first_with_second_and_third
    t = create_ticket(requester_id: @agent.id, custom_field: { 'test_custom_country_1' => 'Australia' })
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_state' => 'Queensland', 'test_custom_city' => 'Brisbane' })
    put :update, construct_params({ id: t.display_id }, params)
    t = Helpdesk::Ticket.find(t.id)
    match_json(update_ticket_pattern(params, t))
    match_json(update_ticket_pattern({}, t))
    assert_response 200
    assert_equal t.custom_field["test_custom_state_#{@account.id}"], 'Queensland'
    assert_equal t.custom_field["test_custom_city_#{@account.id}"], 'Brisbane'
  end

  def test_update_with_nested_custom_fields_without_first_with_second_only
    t = create_ticket(requester_id: @agent.id, custom_field: { 'test_custom_country_1' => 'Australia' })
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_state' => 'Queensland' })
    put :update, construct_params({ id: t.display_id }, params)
    t = Helpdesk::Ticket.find(t.id)
    match_json(update_ticket_pattern(params, t.reload))
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.custom_field["test_custom_state_#{@account.id}"], 'Queensland'
  end

  def test_update_with_nested_custom_fields_without_first_with_third_only
    t = create_ticket(requester_id: @agent.id, custom_field: { 'test_custom_country_1' => 'Australia', 'test_custom_state_1' => 'Queensland' })
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_city' => 'Brisbane' })
    put :update, construct_params({ id: t.display_id }, params)
    t = Helpdesk::Ticket.find(t.id)
    match_json(update_ticket_pattern(params, t.reload))
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
    assert_equal t.custom_field["test_custom_city_#{@account.id}"], 'Brisbane'
  end

  def test_update_with_nested_custom_fields_without_second_with_third
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_city' => 'Brisbane' })
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_state'), :conditional_not_blank, child: 'test_custom_city')])
  end

  def test_update_with_nested_custom_fields_required_without_second_level
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia' })
    ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
    ticket_field.update_attribute(:required, true)
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required, false)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_state'), :not_included, code: :missing_field, list: 'New South Wales,Queensland')])
  end

  def test_update_with_nested_custom_fields_required_without_third_level
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash.merge(custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'Queensland' })
    ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
    ticket_field.update_attribute(:required, true)
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required, false)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_city'), :not_included, code: :missing_field, list: 'Brisbane')])
  end

  def test_update_with_nested_custom_fields_required_for_closure_without_second_level
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4, custom_fields: { 'test_custom_country' => 'Australia' })
    ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
    ticket_field.update_attribute(:required_for_closure, true)
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_state'), :not_included, code: :missing_field, list: 'New South Wales,Queensland')])
  end

  def test_update_with_nested_custom_fields_required_for_closure_without_third_level
    t = create_ticket(requester_id: @agent.id)
    params = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 4, custom_fields: { 'test_custom_country' => 'Australia', 'test_custom_state' => 'Queensland' })
    ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
    ticket_field.update_attribute(:required_for_closure, true)
    put :update, construct_params({ id: t.display_id }, params)
    ticket_field.update_attribute(:required_for_closure, false)
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('test_custom_city'), :not_included, code: :missing_field, list: 'Brisbane')])
  end

  def test_update_source_of_twitter_ticket_fails
    ticket = create_twitter_ticket
    params = { source: 1 }
    put :update, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('source', :source_update_not_permitted, sources: Helpdesk::Source.api_unpermitted_sources_for_update.join(','))])
  end

  def test_update_source_of_facebook_ticket_fails
    ticket = create_ticket_from_fb_post
    params = { source: 1 }
    put :update, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('source', :source_update_not_permitted, sources: Helpdesk::Source.api_unpermitted_sources_for_update.join(','))])
  end

  def test_create_ticket_with_custom_source
    Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
    custom_source = create_custom_source
    params = {
      requester_id: @agent.id,
      status: 2,
      priority: 2,
      type: 'Feature Request',
      source: custom_source.account_choice_id,
      description: Faker::Lorem.characters(15),
      subject: Faker::Lorem.characters(15)
    }
    post :create, construct_params({}, params)
    assert_response 201
    result = JSON.parse(response.body)
    assert_equal custom_source.account_choice_id, result['source']
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
    custom_source.try(:destroy)
  end

  def test_create_ticket_with_custom_source_without_lp
    custom_source = create_custom_source
    params = {
      requester_id: @agent.id,
      status: 2,
      priority: 2,
      type: 'Feature Request',
      source: custom_source.account_choice_id,
      description: Faker::Lorem.characters(15),
      subject: Faker::Lorem.characters(15)
    }
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('source', :not_included, list: api_ticket_sources.join(','))])
  ensure
    custom_source.try(:destroy)
  end

  def test_create_ticket_with_archived_custom_source
    custom_source = create_custom_source(deleted: true)
    assert custom_source.deleted
    Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
    params = {
      requester_id: @agent.id,
      status: 2,
      priority: 2,
      type: 'Feature Request',
      source: custom_source.account_choice_id,
      description: Faker::Lorem.characters(15),
      subject: Faker::Lorem.characters(15)
    }
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('source', :not_included, list: api_ticket_sources.join(','))])
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
    custom_source.try(:destroy)
  end

  def test_update_ticket_with_custom_source
    ticket = create_ticket(requester_id: @agent.id)
    custom_source = create_custom_source
    Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
    params = { source: custom_source.account_choice_id }
    put :update, construct_params({ id: ticket.display_id }, params)
    assert_response 200
    result = JSON.parse(response.body)
    assert_equal custom_source.account_choice_id, result['source']
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
    custom_source.try(:destroy)
    ticket.try(:destroy)
  end

  def test_update_ticket_with_custom_source_without_lp
    ticket = create_ticket(requester_id: @agent.id)
    custom_source = create_custom_source
    params = { source: custom_source.account_choice_id }
    put :update, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('source', :not_included, list: api_update_ticket_sources.join(','))])
  ensure
    custom_source.try(:destroy)
    ticket.try(:destroy)
  end

  def test_update_ticket_with_archived_custom_source
    custom_source = create_custom_source(deleted: true)
    assert custom_source.deleted
    ticket = create_ticket(requester_id: @agent.id)
    Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
    params = { source: custom_source.account_choice_id }
    put :update, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('source', :not_included, list: api_update_ticket_sources.join(','))])
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
    custom_source.try(:destroy)
    ticket.try(:destroy)
  end

  def test_update_source_of_facebook_ticket_fails_with_custom_source_lp
    ticket = create_ticket_from_fb_post
    Account.current.stubs(:ticket_source_revamp_enabled?).returns(true)
    params = { source: 1 }
    put :update, construct_params({ id: ticket.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern('source', :source_update_not_permitted, sources: Helpdesk::Source.api_unpermitted_sources_for_update.join(','))])
  ensure
    Account.current.unstub(:ticket_source_revamp_enabled?)
    ticket.try(:destroy)
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
    User.any_instance.stubs(:has_ticket_permission?).with(ticket).returns(false)
    put :update, construct_params({ id: ticket.display_id }, update_ticket_params_hash)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:has_ticket_permission?)
  end

  def test_update_verify_permission_ticket_trashed
    Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
    put :update, construct_params({ id: ticket.display_id }, update_ticket_params_hash)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
  end

  def test_delete_has_ticket_permission_invalid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false)
    User.any_instance.stubs(:group_ticket_permission).returns(false)
    User.any_instance.stubs(:assigned_ticket_permission).returns(false)
    ticket = create_ticket
    delete :destroy, construct_params(id: ticket.display_id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
  end

  def test_delete_has_ticket_permission_valid
    t = create_ticket(ticket_params_hash)
    User.any_instance.stubs(:can_view_all_tickets?).returns(true)
    User.any_instance.stubs(:group_ticket_permission).returns(false)
    User.any_instance.stubs(:assigned_ticket_permission).returns(false)
    delete :destroy, construct_params(id: t.display_id)
    assert_response 204
  ensure
    User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
  end

  def test_delete_group_ticket_permission_invalid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false)
    User.any_instance.stubs(:group_ticket_permission).returns(true)
    User.any_instance.stubs(:assigned_ticket_permission).returns(false)
    Helpdesk::Ticket.stubs(:group_tickets_permission).returns([])
    ticket = create_ticket
    delete :destroy, construct_params(id: ticket.display_id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
    Helpdesk::Ticket.unstub(:group_tickets_permission)
  end

  def test_delete_assigned_ticket_invalid_permission
    User.any_instance.stubs(:can_view_all_tickets?).returns(false)
    User.any_instance.stubs(:group_ticket_permission).returns(false)
    User.any_instance.stubs(:assigned_ticket_permission).returns(true)
    Helpdesk::Ticket.stubs(:assigned_tickets_permission).returns([])
    delete :destroy, construct_params(id: ticket.display_id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
    Helpdesk::Ticket.unstub(:assigned_tickets_permission)
  end

  def test_delete_group_ticket_permission_valid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false)
    User.any_instance.stubs(:group_ticket_permission).returns(true)
    User.any_instance.stubs(:assigned_ticket_permission).returns(false)
    group = create_group_with_agents(@account, agent_list: [@agent.id])
    t = create_ticket(ticket_params_hash.merge(group_id: group.id))
    delete :destroy, construct_params(id: t.display_id)
    assert_response 204
  ensure
    User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
  end

  def test_delete_group_ticket_permission_internal_agent_valid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false)
    User.any_instance.stubs(:group_ticket_permission).returns(true)
    User.any_instance.stubs(:assigned_ticket_permission).returns(false)
    group = create_group_with_agents(@account, agent_list: [@agent.id])
    t = create_ticket(ticket_params_hash.merge(internal_group_id: group.id))
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    delete :destroy, construct_params(id: t.display_id)
    assert_response 204
  ensure
    User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
    Account.any_instance.unstub(:shared_ownership_enabled?)
  end

  def test_delete_assigned_ticket_permission_valid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false)
    User.any_instance.stubs(:group_ticket_permission).returns(false)
    User.any_instance.stubs(:assigned_ticket_permission).returns(true)
    t = create_ticket(ticket_params_hash)
    Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(@agent.id)
    delete :destroy, construct_params(id: t.display_id)
    assert_response 204
  ensure
    User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
    Helpdesk::Ticket.any_instance.unstub(:responder_id)
  end

  def test_delete_assigned_ticket_permission_internal_agent_valid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false)
    User.any_instance.stubs(:group_ticket_permission).returns(false)
    User.any_instance.stubs(:assigned_ticket_permission).returns(true)
    t = create_ticket(ticket_params_hash)
    Helpdesk::Ticket.any_instance.stubs(:internal_agent_id).returns(@agent.id)
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    delete :destroy, construct_params(id: t.display_id)
    assert_response 204
  ensure
    Helpdesk::Ticket.any_instance.unstub(:responder_id)
    User.any_instance.unstub(:can_view_all_tickets?, :group_ticket_permission, :assigned_ticket_permission)
    Account.any_instance.unstub(:shared_ownership_enabled?)
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
    User.any_instance.stubs(:privilege?).with(:delete_ticket).returns(false)
    put :restore, construct_params(id: Helpdesk::Ticket.first.display_id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:privilege?)
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
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
  end

  def test_restore_without_ticket_privilege
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    t = create_ticket
    t.update_column(:deleted, true)
    put :restore, construct_params(id: t.display_id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:has_ticket_permission?)
  end

  def test_show_object_not_present
    get :show, controller_params(id: 999)
    assert_response :missing
    assert_equal ' ', @response.body
    assert_equal response.status, 404
    assert_includes response.headers['Content-Type'], 'application/json'
  end

  def test_show_without_permission
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    get :show, controller_params(id: Helpdesk::Ticket.first.display_id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  ensure
    User.any_instance.unstub(:has_ticket_permission?)
  end

  def test_update_deleted
    ticket.update_column(:deleted, true)
    put :update, construct_params({ id: ticket.display_id }, source: 2)
    assert_response 405
    response.body.must_match_json_expression(base_error_pattern('method_not_allowed', methods: 'GET', fired_method: 'PUT'))
    assert_equal 'GET', response.headers['Allow']
    ticket.update_column(:deleted, false)
  end

  def test_destroy_deleted
    ticket.update_column(:deleted, true)
    delete :destroy, construct_params(id: ticket.display_id)
    assert_response 405
    response.body.must_match_json_expression(base_error_pattern('method_not_allowed', methods: 'GET', fired_method: 'DELETE'))
    assert_equal 'GET', response.headers['Allow']
    ticket.update_column(:deleted, false)
  end

  def test_restore_not_deleted
    ticket.update_column(:deleted, false)
    put :restore, construct_params(id: ticket.display_id)
    assert_response :missing
  end

  def test_show
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    ticket.update_column(:deleted, false)
    get :show, controller_params(id: ticket.display_id)
    assert_response 200
    match_json(show_ticket_pattern({}, ticket))
    result = parse_response(@response.body)
    assert_equal result['nr_due_by'], nil
    assert_equal result['nr_escalated'], false
  ensure
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_show_with_conversations
    ticket.update_column(:deleted, false)
    get :show, controller_params(id: ticket.display_id, include: 'conversations')
    assert_response 200
    match_json(show_ticket_pattern_with_notes(ticket))
  end

  def test_show_with_sla_policy
    ticket.deleted = false
    get :show, controller_params(id: ticket.display_id, include: 'stats, sla_policy')
    assert_response 200
    param_object = OpenStruct.new(:stats => true, :sla_policy => true)
    match_json(show_ticket_pattern_with_association(ticket, param_object))
  end

  def test_show_with_requester
    ticket.update_column(:deleted, false)
    get :show, controller_params(id: ticket.display_id, include: 'requester')
    assert_response 200
    param_object = OpenStruct.new(:requester => true)
    match_json(show_ticket_pattern_with_association(ticket, param_object))
  end

  def test_show_with_company
    t = ticket
    t.update_column(:deleted, false)
    company = create_company
    t.update_column(:owner_id, company.id)
    get :show, controller_params(id: ticket.display_id, include: 'company')
    assert_response 200
    param_object = OpenStruct.new(:company => true)
    match_json(show_ticket_pattern_with_association(ticket, param_object))
  end

  def test_show_with_stats
    t = ticket
    t.deleted = false
    t.status = 5
    t.save!

    get :show, controller_params(id: t.display_id, include: 'stats')
    assert_response 200
    param_object = OpenStruct.new(:stats => true)
    match_json(show_ticket_pattern_with_association(t, param_object))
  end

  def test_show_with_twitter_ticket
    ticket = create_twitter_ticket
    get :show, controller_params(id: ticket.display_id)
    assert_response 200
    match_json(show_ticket_pattern({}, ticket))
  end

  def test_show_with_facebook_ticket
    ticket = create_ticket_from_fb_post
    get :show, controller_params(id: ticket.display_id)
    assert_response 200
    match_json(show_ticket_pattern({},ticket))
  end

  def test_show_with_all_associations
    t = ticket
    t.deleted = false
    t.status = 5
    t.save!
    t.reload
    get :show, controller_params(id: t.display_id, include: 'conversations,requester,company,stats')
    assert_response 200
    param_object = OpenStruct.new(:notes => true, :requester => true, :company => true, :stats => true)
    match_json(show_ticket_pattern_with_association(t, param_object))
  end

  def test_show_with_empty_include
    ticket.update_column(:deleted, false)
    get :show, controller_params(id: ticket.display_id, include: '')
    assert_response 400
    match_json([bad_request_error_pattern('include', :not_included, list: 'conversations, requester, company, stats, sla_policy')])
  end

  def test_show_with_wrong_type_include
    ticket.update_column(:deleted, false)
    get :show, controller_params(id: ticket.display_id, include: ['test'])
    assert_response 400
    match_json([bad_request_error_pattern('include', :datatype_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: 'Array')])
  end

  def test_show_with_invalid_param_value
    ticket.update_column(:deleted, false)
    get :show, controller_params(id: ticket.display_id, include: 'test')
    assert_response 400
    match_json([bad_request_error_pattern('include', :not_included, list: 'conversations, requester, company, stats, sla_policy')])
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
    match_json(show_deleted_ticket_pattern({}, ticket))
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

    expected = Helpdesk::Ticket.where(deleted: 0, spam: 0).created_in(Helpdesk::Ticket.created_in_last_month).update_all(responder_id: @agent.id)
    get :index, controller_params
    assert_response 200
    response = parse_response @response.body
    assert_equal expected, response.size
  ensure
    Agent.any_instance.unstub(:ticket_permission)
  end

  def test_index_with_invalid_sort_params
    get :index, controller_params(order_type: 'test', order_by: 'test')
    assert_response 400
    pattern = [bad_request_error_pattern('order_type', :not_included, list: 'asc,desc')]
    pattern << bad_request_error_pattern('order_by', :not_included, list: 'due_by,created_at,updated_at,priority,status')
    match_json(pattern)
  end

  def test_index_sort_by_due_by_with_sla_disabled
    Account.any_instance.stubs(:sla_management_enabled?).returns(false)
    get :index, controller_params(order_type: 'test', order_by: 'due_by')
    assert_response 400
    pattern = [bad_request_error_pattern('order_type', :not_included, list: 'asc,desc')]
    pattern << bad_request_error_pattern('order_by', :not_included, list: 'created_at,updated_at,priority,status')
    match_json(pattern)
  ensure
    Account.any_instance.unstub(:sla_management_enabled?)
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
    pattern << bad_request_error_pattern('company_id', :absent_in_db, resource: :company, attribute: :company_id)
    pattern << bad_request_error_pattern('requester_id', :absent_in_db, resource: :contact, attribute: :requester_id)
    assert_response 400
    match_json pattern
  end

  def test_index_with_invalid_email_in_params
    get :index, controller_params(email: Faker::Internet.email)
    pattern = [bad_request_error_pattern('email', :absent_in_db, resource: :contact, attribute: :email)]
    assert_response 400
    match_json pattern
  end

  def test_index_with_invalid_params_type
    get :index, controller_params(company_id: 'a', requester_id: 'b')
    pattern = [bad_request_error_pattern('company_id', :datatype_mismatch, expected_data_type: 'Positive Integer')]
    pattern << bad_request_error_pattern('requester_id', :datatype_mismatch, expected_data_type: 'Positive Integer')
    assert_response 400
    match_json pattern
  end

  def test_index_with_monitored_by
    ticket = create_ticket
    subscription = FactoryGirl.build(:subscription, account_id: @account.id,
                                     ticket_id: ticket.id,
                                     user_id: @agent.id)
    subscription.save
    get :index, controller_params(filter: 'watching')
    assert_response 200
    response = parse_response @response.body
    assert response.any? {|record| record["id"] == ticket.display_id}, "Ticket not found in Watching!"
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
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    get :index, controller_params
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
    ticket = response.first
    assert_equal ticket['nr_due_by'], nil
    assert_equal ticket['nr_escalated'], false
  ensure
    Account.any_instance.unstub(:next_response_sla_enabled?)
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
    ticket = @account.tickets.where(deleted: false, spam: false).first
    ticket.update_attributes(spam: true, created_at: 2.months.ago)
    get :index, controller_params(filter: 'spam')
    assert_response 200
    response = parse_response @response.body
    assert response.any? {|record| record["id"] == ticket.display_id}, "Ticket not found in Spam!"
  end

  def test_index_with_spam_and_deleted
    pattern = /SELECT  `helpdesk_tickets`.* FROM/
    from = 'WHERE '
    to = ' ORDER BY'
    query = trace_query_condition(pattern, from, to) { get :index, controller_params(filter: 'spam', updated_since: '2009-09-09') }
    assert_equal "`helpdesk_tickets`.`account_id` = 1 AND `helpdesk_tickets`.`deleted` = 0 AND `helpdesk_tickets`.`spam` = 1 AND (helpdesk_tickets.updated_at >= '2009-09-09 00:00:00')", query
    query = trace_query_condition(pattern, from, to) { get :index, controller_params(filter: 'deleted', updated_since: '2009-09-09') }
    assert_equal "`helpdesk_tickets`.`account_id` = 1 AND `helpdesk_tickets`.`deleted` = 1 AND `helpdesk_schema_less_tickets`.`boolean_tc02` = 0 AND (helpdesk_tickets.updated_at >= '2009-09-09 00:00:00')", query
    query = trace_query_condition(pattern, from, to) { get :index, controller_params(filter: 'spam') }
    assert_equal '`helpdesk_tickets`.`account_id` = 1 AND `helpdesk_tickets`.`deleted` = 0 AND `helpdesk_tickets`.`spam` = 1', query
    query = trace_query_condition(pattern, from, to) { get :index, controller_params(filter: 'spam', requester_id: 1) }
    assert_equal '`helpdesk_tickets`.`account_id` = 1 AND `helpdesk_tickets`.`deleted` = 0 AND `helpdesk_tickets`.`requester_id` = 1 AND `helpdesk_tickets`.`spam` = 1', query
    query = trace_query_condition(pattern, from, to) { get :index, controller_params }
    assert_match(/`helpdesk_tickets`.`account_id` = 1 AND `helpdesk_tickets`\.`deleted` = 0 AND `helpdesk_tickets`\.`spam` = 0 AND \(helpdesk_tickets.created_at > '.*'\)$/, query)
    query = trace_query_condition(pattern, from, to) { get :index, controller_params(filter: 'spam', company_id: 1) }
    assert_equal '`helpdesk_tickets`.`account_id` = 1 AND `helpdesk_tickets`.`deleted` = 0 AND `helpdesk_tickets`.`owner_id` = 1 AND `helpdesk_tickets`.`spam` = 1', query
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

  def test_index_with_requester_filter
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

    ticket = @account.tickets.where(deleted: 0, spam: 0).first || create_ticket(requester_id: user.id)
    ticket.update_attributes(requester_id: user.id, status: 2)
    get :index, controller_params(filter: 'new_and_my_open', email: user.email)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.count
  end

  def test_index_with_company
    company = create_company
    user = add_new_user(@account)
    sidekiq_inline {
      user.company_id = company.id
      user.save!
    }
    ticket = create_ticket(requester_id: user.id)
    get :index, controller_params(company_id: "#{company.id}")
    assert_response 200

    tkts = Helpdesk::Ticket.where(owner_id: company.id)
    pattern = tkts.map { |tkt| index_ticket_pattern(tkt) }
    match_json(pattern)
  end

  def test_index_with_filter_and_requester
    user1 = add_new_user(@account)
    user2 = add_new_user(@account)
    ticket = @account.tickets.where(deleted: 0, spam: 0).first || create_ticket(requester_id: user1.id)
    Helpdesk::Ticket.update_all(requester_id: user1.id)
    get :index, controller_params(filter: 'new_and_my_open', requester_id: "#{user2.id}")
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.count

    ticket.update_attributes(requester_id: user2.id, status: 2)
    get :index, controller_params(filter: 'new_and_my_open', requester_id: "#{user2.id}")
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.count
  end

  def test_index_with_filter_and_company
    Helpdesk::Ticket.update_all(status: 3)
    user = get_user_with_default_company
    user_id = user.id
    company_id = user.company.id
    Helpdesk::Ticket.where(deleted: 0, spam: 0).update_all(
        requester_id: nil, owner_id: nil
    )

    get :index, controller_params(filter: 'new_and_my_open', company_id: "#{company_id}")
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.count

    tkt = Helpdesk::Ticket.first
    tkt.update_attributes(
        status: 2, requester_id: user_id,
        owner_id: company_id, responder_id: nil
    )
    get :index, controller_params(
        filter: 'new_and_my_open',
        company_id: "#{company_id}"
    )
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.count
  end

  def test_index_with_company_and_requester
    company = Company.first
    user1 = User.first
    user2 = User.first(2).last
    sidekiq_inline { user1.update_attributes(company_id: company.id) }
    user1.reload

    expected_size = @account.tickets.where(deleted: 0, spam: 0, requester_id: user1.id, owner_id: company.id).count
    get :index, controller_params(company_id: company.id, requester_id: "#{user1.id}")
    assert_response 200
    response = parse_response @response.body
    assert_equal expected_size, response.size

    sidekiq_inline { user2.update_attributes(company_id: nil) }
    get :index, controller_params(company_id: company.id, requester_id: "#{user2.id}")
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size
  end

  def test_index_with_requester_filter_company
    remove_wrap_params
    user = get_user_with_default_company
    user_id = user.id
    company = user.company
    new_company = create_company
    add_new_user(@account, customer_id: new_company.id)
    Helpdesk::Ticket.where(deleted: 0, spam: 0).update_all(requester_id: new_company.users.map(&:id).first)
    get :index, controller_params(company_id: company.id,
                                  requester_id: "#{User.first.id}", filter: 'new_and_my_open')
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size

    Helpdesk::Ticket.where(deleted: 0, spam: 0).first.update_attributes(requester_id: user_id,
                                                                        status: 2, responder_id: nil)
    get :index, controller_params(company_id: company.id,
                                  requester_id: "#{user_id}", filter: 'new_and_my_open')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_index_with_requester_nil
    ticket = create_ticket
    ticket.requester.destroy
    get :index, controller_params(include: 'requester')
    assert_response 200
    requester_hash = JSON.parse(response.body).select { |x| x['id'] == ticket.display_id }.first['requester']
    ticket.destroy
    assert requester_hash.nil?
  end

  def test_index_with_dates
    tkt = create_ticket
    tkt.update_column(:created_at, 2.days.ago)
    tkt.update_column(:updated_at, 1.days.ago)
    get :index, controller_params(updated_since: Time.zone.now.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert !response.any? {|record| record["id"] == tkt.display_id}, "Ticket should be present in this filter!"

    tkt.update_column(:updated_at, 1.days.from_now)
    get :index, controller_params(updated_since: Time.zone.now.iso8601)
    assert_response 200
    response = parse_response @response.body
    assert response.any? {|record| record["id"] == tkt.display_id}, "Ticket not present in this filter!" 
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

  def test_index_with_requester
    get :index, controller_params(include: 'requester')
    assert_response 200
    response = parse_response @response.body
    tkts =  Helpdesk::Ticket.where(deleted: 0, spam: 0)
                .created_in(Helpdesk::Ticket.created_in_last_month)
                .order('created_at DESC')
                .limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
    assert_equal tkts.count, response.size
    param_object = OpenStruct.new(:requester => true)
    param_object.requester = true
    pattern = tkts.map do |tkt|
      index_ticket_pattern_with_associations(tkt, param_object)
    end
    match_json(pattern)
  end

  def test_index_with_stats
    get :index, controller_params(include: 'stats')
    assert_response 200
    response = parse_response @response.body
    tkts =  Helpdesk::Ticket.where(deleted: 0, spam: 0)
                .created_in(Helpdesk::Ticket.created_in_last_month)
                .order('created_at DESC')
                .limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
    assert_equal tkts.count, response.size
    param_object = OpenStruct.new(:stats => true)
    pattern = tkts.map do |tkt|
      index_ticket_pattern_with_associations(tkt, param_object)
    end
    match_json(pattern)
  end

  def test_index_with_company_side_load
    get :index, controller_params(include: 'company')
    assert_response 200
    response = parse_response @response.body
    tkts =  Helpdesk::Ticket.where(deleted: 0, spam: 0)
                .created_in(Helpdesk::Ticket.created_in_last_month)
                .order('created_at DESC')
                .limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
    assert_equal tkts.count, response.size
    param_object = OpenStruct.new(:company => true)
    pattern = tkts.map do |tkt|
      index_ticket_pattern_with_associations(tkt, param_object)
    end
    match_json(pattern)
  end

  def test_index_with_empty_include
    get :index, controller_params(include: '')
    assert_response 400
    match_json([bad_request_error_pattern(
                    'include', :not_included,
                    list: 'requester, stats, company, description')]
    )
  end

  def test_index_with_wrong_type_include
    get :index, controller_params(include: ['test'])
    assert_response 400
    match_json([bad_request_error_pattern('include', :datatype_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: 'Array')])
  end

  def test_index_with_invalid_param_value
    get :index, controller_params(include: 'test')
    assert_response 400
    match_json([bad_request_error_pattern(
                    'include', :not_included,
                    list: 'requester, stats, company, description')]
    )
  end

  def test_index_with_spam_count_es_enabled
    Account.any_instance.stubs(:count_es_enabled?).returns(true)
    Account.any_instance.stubs(:api_es_enabled?).returns(true)
    Account.any_instance.stubs(:dashboard_new_alias?).returns(true)
    t = create_ticket(spam: true)
    stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t.id).to_json, status: 200)
    get :index, controller_params(filter: 'spam')
    assert_response 200
    param_object = OpenStruct.new
    pattern = []
    pattern.push(index_ticket_pattern_with_associations(t, param_object))
    match_json(pattern)
  ensure
    Account.any_instance.unstub(:count_es_enabled?)
    Account.any_instance.unstub(:dashboard_new_alias?)
    Account.any_instance.unstub(:api_es_enabled?)
  end

  def test_index_with_new_and_my_open_count_es_enabled
    Account.any_instance.stubs(:count_es_enabled?).returns(:true)
    Account.any_instance.stubs(:api_es_enabled?).returns(:true)
    Account.any_instance.stubs(:dashboard_new_alias?).returns(:true)
    t = create_ticket(status: 2)
    stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t.id).to_json, status: 200)
    get :index, controller_params(filter: 'new_and_my_open')
    assert_response 200
    param_object = OpenStruct.new
    pattern = []
    pattern.push(index_ticket_pattern_with_associations(t, param_object))
    match_json(pattern)
  ensure
    Account.any_instance.unstub(:count_es_enabled?)
    Account.any_instance.unstub(:api_es_enabled?)
    Account.any_instance.unstub(:dashboard_new_alias?)
  end

  def test_index_with_stats_with_count_es_enabled
    Account.any_instance.stubs(:count_es_enabled?).returns(:true)
    Account.any_instance.stubs(:api_es_enabled?).returns(:true)
    Account.any_instance.stubs(:dashboard_new_alias?).returns(:true)
    t = create_ticket
    stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t.id).to_json, status: 200)
    get :index, controller_params(include: 'stats')
    assert_response 200
    param_object = OpenStruct.new(:stats => true)
    pattern = []
    pattern.push(index_ticket_pattern_with_associations(t, param_object))
    match_json(pattern)
  ensure
    Account.any_instance.unstub(:count_es_enabled?)
    Account.any_instance.unstub(:api_es_enabled?)
    Account.any_instance.unstub(:dashboard_new_alias?)
  end

  def test_index_with_requester_with_count_es_enabled
    Account.any_instance.stubs(:count_es_enabled?).returns(:true)
    Account.any_instance.stubs(:api_es_enabled?).returns(:true)
    Account.any_instance.stubs(:dashboard_new_alias?).returns(:true)
    user = add_new_user(@account)
    t = create_ticket(requester_id: user.id)
    stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t.id).to_json, status: 200)
    get :index, controller_params(requester_id: user.id)
    assert_response 200
    param_object = OpenStruct.new
    pattern = []
    pattern.push(index_ticket_pattern_with_associations(t, param_object))
    match_json(pattern)
  ensure
    Account.any_instance.unstub(:count_es_enabled?)
    Account.any_instance.unstub(:api_es_enabled?)
    Account.any_instance.unstub(:dashboard_new_alias?)
  end

  def test_index_with_filter_order_by_with_count_es_enabled
    Account.any_instance.stubs(:count_es_enabled?).returns(:true)
    Account.any_instance.stubs(:api_es_enabled?).returns(:true)
    Account.any_instance.stubs(:dashboard_new_alias?).returns(:true)
    t_1 = create_ticket(status: 2, created_at: 10.days.ago)
    t_2 = create_ticket(status: 3, created_at: 11.days.ago)
    stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t_1.id, t_2.id).to_json, status: 200)
    get :index, controller_params(order_by: 'status')
    assert_response 200
    param_object = OpenStruct.new
    pattern = []
    pattern.push(index_ticket_pattern_with_associations(t_2, param_object))
    pattern.push(index_ticket_pattern_with_associations(t_1, param_object))
    match_json(pattern)
  ensure
    Account.any_instance.unstub(:count_es_enabled?)
    Account.any_instance.unstub(:api_es_enabled?)
    Account.any_instance.unstub(:dashboard_new_alias?)
  end

  def test_index_with_default_filter_order_type_count_es_enabled
    Account.any_instance.stubs(:count_es_enabled?).returns(:true)
    Account.any_instance.stubs(:api_es_enabled?).returns(:true)
    Account.any_instance.stubs(:dashboard_new_alias?).returns(:true)
    t_1 = create_ticket(created_at: 10.days.ago)
    t_2 = create_ticket(created_at: 11.days.ago)
    stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t_2.id, t_1.id).to_json, status: 200)
    get :index, controller_params(order_type: 'asc')
    assert_response 200
    param_object = OpenStruct.new
    pattern = []
    pattern.push(index_ticket_pattern_with_associations(t_1, param_object))
    pattern.push(index_ticket_pattern_with_associations(t_2, param_object))
    match_json(pattern)
  ensure
    Account.any_instance.unstub(:count_es_enabled?)
    Account.any_instance.unstub(:api_es_enabled?)
    Account.any_instance.unstub(:dashboard_new_alias?)
  end

  def test_index_updated_since_count_es_enabled
    Account.any_instance.stubs(:count_es_enabled?).returns(:true)
    Account.any_instance.stubs(:api_es_enabled?).returns(:true)
    Account.any_instance.stubs(:dashboard_new_alias?).returns(:true)
    t = create_ticket(updated_at: 2.days.from_now)
    stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t.id).to_json, status: 200)
    get :index, controller_params(updated_since: Time.zone.now.iso8601)
    assert_response 200
    param_object = OpenStruct.new
    pattern = []
    pattern.push(index_ticket_pattern_with_associations(t, param_object))
    match_json(pattern)
  ensure
    Account.any_instance.unstub(:count_es_enabled?)
    Account.any_instance.unstub(:api_es_enabled?)
    Account.any_instance.unstub(:dashboard_new_alias?)
  end

  def test_index_with_company_count_es_enabled
    Account.any_instance.stubs(:count_es_enabled?).returns(:true)
    Account.any_instance.stubs(:api_es_enabled?).returns(:true)
    Account.any_instance.stubs(:dashboard_new_alias?).returns(:true)
    company = create_company
    user = add_new_user(@account)
    sidekiq_inline {
      user.company_id = company.id
      user.save!
    }
    t = create_ticket(requester_id: user.id)
    stub_request(:get, %r{^http://localhost:9201.*?$}).to_return(body: count_es_response(t.id).to_json, status: 200)
    get :index, controller_params(company_id: "#{company.id}")
    assert_response 200
    param_object = OpenStruct.new
    pattern = []
    pattern.push(index_ticket_pattern_with_associations(t, param_object))
    match_json(pattern)
  ensure
    Account.any_instance.unstub(:count_es_enabled?)
    Account.any_instance.unstub(:api_es_enabled?)
    Account.any_instance.unstub(:dashboard_new_alias?)
  end

  def test_index_with_description_in_include_without_description_by_default_feature
    Account.any_instance.stubs(:description_by_default_enabled?).returns(false)
    get :index, controller_params(include: 'description')
    assert_response 200
    response = parse_response @response.body
    tkts =  Helpdesk::Ticket.where(deleted: 0, spam: 0)
                .created_in(Helpdesk::Ticket.created_in_last_month)
                .order('created_at DESC')
                .limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
    assert_equal tkts.count, response.size
    param_object = OpenStruct.new()
    pattern = tkts.map do |tkt|
      index_ticket_pattern_with_associations(tkt, param_object, [:description, :description_text])
    end
    match_json(pattern)
    Account.any_instance.unstub(:description_by_default_enabled?)
  end

  def test_index_with_description_in_include_with_description_by_default_feature
    Account.any_instance.stubs(:description_by_default_enabled?).returns(true)
    get :index, controller_params(include: 'description')
    assert_response 200
    response = parse_response @response.body
    tkts =  Helpdesk::Ticket.where(deleted: 0, spam: 0)
                .created_in(Helpdesk::Ticket.created_in_last_month)
                .order('created_at DESC')
                .limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
    assert_equal tkts.count, response.size
    param_object = OpenStruct.new()
    pattern = tkts.map do |tkt|
      index_ticket_pattern_with_associations(tkt, param_object, [:description, :description_text])
    end
    match_json(pattern)
    Account.any_instance.unstub(:description_by_default_enabled?)
  end

  def test_index_without_description_in_include_without_description_by_default_feature
    Account.any_instance.stubs(:description_by_default_enabled?).returns(false)
    get :index, controller_params
    assert_response 200
    response = parse_response @response.body
    tkts =  Helpdesk::Ticket.where(deleted: 0, spam: 0)
                .created_in(Helpdesk::Ticket.created_in_last_month)
                .order('created_at DESC')
                .limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
    assert_equal tkts.count, response.size
    param_object = OpenStruct.new()
    pattern = tkts.map do |tkt|
      index_ticket_pattern_with_associations(tkt, param_object)
    end
    match_json(pattern)
    Account.any_instance.unstub(:description_by_default_enabled?)
  end

  def test_index_without_description_in_include_with_description_by_default_feature
    Account.any_instance.stubs(:description_by_default_enabled?).returns(true)
    get :index, controller_params()
    assert_response 200
    response = parse_response @response.body
    tkts =  Helpdesk::Ticket.where(deleted: 0, spam: 0)
                .created_in(Helpdesk::Ticket.created_in_last_month)
                .order('created_at DESC')
                .limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
    assert_equal tkts.count, response.size
    param_object = OpenStruct.new()
    pattern = tkts.map do |tkt|
      index_ticket_pattern_with_associations(tkt, param_object, [:description, :description_text])
    end
    match_json(pattern)
    Account.any_instance.unstub(:description_by_default_enabled?)
  end  

  def test_show_with_conversations_exceeding_limit
    ticket.update_column(:deleted, false)
    4.times do
      create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
    end
    stub_const(ConversationConstants, 'MAX_INCLUDE', 3) do
      get :show, controller_params(id: ticket.display_id, include: 'conversations')
    end
    match_json(show_ticket_pattern_with_notes(ticket, 3))
    assert_response 200
    response = parse_response @response.body
    assert_equal 3, response['conversations'].size
    assert ticket.reload.notes.visible.exclude_source('meta').size > 3
  end

  def test_show_spam
    t = ticket
    t.update_column(:spam, true)
    get :show, controller_params(id: t.display_id)
    match_json(show_ticket_pattern({}, ticket))
    assert_response 200
    t.update_column(:spam, false)
  end

  def test_delete_spam
    t = ticket
    t.update_column(:spam, true)
    delete :destroy, controller_params(id: t.display_id)
    assert_response 405
    response.body.must_match_json_expression(base_error_pattern('method_not_allowed', methods: 'GET', fired_method: 'DELETE'))
    assert_equal 'GET', response.headers['Allow']
    t.update_column(:spam, false)
  end

  def test_update_spam
    t = ticket
    t.update_column(:spam, true)
    put :update, construct_params({ id: t.display_id }, update_ticket_params_hash)
    assert_response 405
    response.body.must_match_json_expression(base_error_pattern('method_not_allowed', methods: 'GET', fired_method: 'PUT'))
    assert_equal 'GET', response.headers['Allow']
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
    match_json([bad_request_error_pattern('tags', :array_datatype_mismatch, expected_data_type: String)])
    assert_response 400
  end

  def test_update_array_fields_with_compacting_array
    tag = Faker::Name.name
    params_hash = update_ticket_params_hash
    t = ticket
    put :update, construct_params({ id: t.display_id }, tags: [tag, '', ''])
    response_pattern = ticket_pattern({ tags: [tag] }, t.reload)
    response_pattern.merge!(ticket_association_pattern(t)) if t.associated_ticket?
    match_json(response_pattern)
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
    match_json(update_ticket_pattern({ due_by: due_by, fr_due_by: fr_due_by.utc.iso8601 }, t.reload))
    assert_response 200
  end

  def test_create_with_all_default_fields_required_invalid
    default_non_required_fiels = Helpdesk::TicketField.where(required: false, default: 1)
    type_field_names = Account.current.ticket_type_values.map(&:value).join(',')
    default_non_required_fiels.map { |x| x.toggle!(:required) }
    post :create, construct_params({},  requester_id: @agent.id)
    match_json([bad_request_error_pattern('description', :datatype_mismatch, code: :missing_field, expected_data_type: String),
                bad_request_error_pattern('subject', :datatype_mismatch, code: :missing_field, expected_data_type: String),
                bad_request_error_pattern('group_id', :datatype_mismatch, code: :missing_field, expected_data_type: 'Positive Integer'),
                bad_request_error_pattern('responder_id', :datatype_mismatch, code: :missing_field, expected_data_type: 'Positive Integer'),
                bad_request_error_pattern('product_id', :datatype_mismatch, code: :missing_field, expected_data_type: 'Positive Integer'),
                bad_request_error_pattern('priority', :not_included, code: :missing_field, list: '1,2,3,4'),
                bad_request_error_pattern('status', :not_included, code: :missing_field, list: '2,3,4,5,6,7'),
                bad_request_error_pattern('type', :not_included, code: :missing_field, list: ticket_type_list)])
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
                                   type: 'Feature Request',
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
    type_field_names = Account.current.ticket_type_values.map(&:value).join(',')
    default_non_required_fiels = Helpdesk::TicketField.where(required: false, default: 1)
    default_non_required_fiels.map { |x| x.toggle!(:required) }
    put :update, construct_params({ id: ticket.display_id },  subject: nil,
                                  description: nil,
                                  group_id: nil,
                                  product_id: nil,
                                  responder_id: nil,
                                  status: nil,
                                  priority: nil,
                                  source: nil,
                                  type: nil
    )
    match_json([bad_request_error_pattern('description',  :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Null'),
                bad_request_error_pattern('group_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'Null'),
                bad_request_error_pattern('responder_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'Null'),
                bad_request_error_pattern('product_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: 'Null'),
                bad_request_error_pattern('priority', :not_included, list: '1,2,3,4'),
                bad_request_error_pattern('status', :not_included, list: '2,3,4,5,6,7'),
                bad_request_error_pattern('type', :not_included, list: ticket_type_list),
                bad_request_error_pattern('source', :not_included, list: '1,2,3,5,6,7,8,9,11,10,12')])
    assert_response 400
  ensure
    default_non_required_fiels.map { |x| x.toggle!(:required) }
  end

  def test_create_with_email_array
    post :create, construct_params({}, ticket_params_hash.except(:email).merge(email: [email: Faker::Internet.email]))
    assert_response 400
    match_json([bad_request_error_pattern('email', :datatype_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_update_with_email_array
    params_hash = { email: [Faker::Internet.email] }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('email', :datatype_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_create_ticket_with_twitter_and_invalid_email
    create_ticket(ticket_params_hash.except(:email).merge(twitter_id: '@test123'))
    params = { email: Faker::Name.name, status: 2, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph, twitter_id: '@test123' }
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern('email', :invalid_format, accepted: 'valid email address')])
  end

  def test_compose_email_without_feature
    Account.any_instance.stubs(:compose_email_enabled?).returns(false)
    params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {})
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({ _action: 'compose_email' }, params)
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: 'compose_email'.titleize))
  ensure
    Account.any_instance.unstub(:compose_email_enabled?)
  end

  def test_compose_email_with_invalid_params
    params = ticket_params_hash.merge(custom_fields: {}, product_id: 2, requester_id: 3, phone: 7, twitter_id: '67', facebook_id: 'ui')
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({ _action: 'compose_email' }, params)
    assert_response 400
    match_json([bad_request_error_pattern('source',  :invalid_field),
                bad_request_error_pattern('product_id',  :invalid_field),
                bad_request_error_pattern('responder_id',  :invalid_field),
                bad_request_error_pattern('requester_id',  :invalid_field),
                bad_request_error_pattern('twitter_id',  :invalid_field),
                bad_request_error_pattern('facebook_id',  :invalid_field),
                bad_request_error_pattern('phone',  :invalid_field)])
  ensure
    Account.any_instance.unstub(:compose_email_enabled?)
  end

  def test_compose_email
    email_config = fetch_email_config
    params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({ _action: 'compose_email' }, params)
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    result = parse_response(@response.body)
    assert_equal true, response.headers.include?('Location')
    assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
    assert_response 201
  end

  def test_compose_with_all_default_fields_required_valid
    default_non_required_fiels = Helpdesk::TicketField.where(required: false, default: 1)
    default_non_required_fiels.map { |x| x.toggle!(:required) }
    default_non_required_fiels.select { |x| x.name == 'product' }.map { |x| x.toggle!(:required) }
    email_config = fetch_email_config
    params = { email: Faker::Internet.email, email_config_id: email_config.id, priority: 2, type: 'Feature Request', description: Faker::Lorem.characters(15), group_id: ticket_params_hash[:group_id], subject: Faker::Lorem.characters(15) }
    post :create, construct_params({ _action: 'compose_email' }, params)
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    match_json(ticket_pattern(params.merge(responder_id: @agent.id, source: 10, status: 5), Helpdesk::Ticket.last))
    assert_response 201
  ensure
    default_non_required_fiels.map { |x| x.toggle!(:required) }
    default_non_required_fiels.select { |x| x.name == 'product' }.map { |x| x.toggle!(:required) }
  end

  def test_compose_with_attachment
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = ticket_params_hash.except(:source, :product_id, :responder_id).merge('attachments' => [file, file2], status: '2', priority: '2', email_config_id: "#{fetch_email_config.id}")
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
    post :create, construct_params({ _action: 'compose_email' }, params)
    response_params = params.except(:tags, :attachments)
    match_json(ticket_pattern(params.merge(status: 2, priority: 2, source: 10, email_config_id: params[:email_config_id].to_i), Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    assert_response 201
    assert Helpdesk::Ticket.last.attachments.count == 2
  ensure
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_compose_email_without_status
    email_config = fetch_email_config
    params = ticket_params_hash.except(:source, :status, :fr_due_by, :due_by, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({ _action: 'compose_email' }, params)
    match_json(ticket_pattern(params.merge(status: 5), Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    result = parse_response(@response.body)
    assert_equal 5, result['status']
    assert_equal true, response.headers.include?('Location')
    assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
    assert_response 201
  end

  def test_compose_email_without_responder_id
    email_config = fetch_email_config
    params = ticket_params_hash.except(:source, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({ _action: 'compose_email' }, params)
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    result = parse_response(@response.body)
    assert_equal @agent.id, result['responder_id']
    assert_equal true, response.headers.include?('Location')
    assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
    assert_response 201
  end

  def test_compose_email_without_status_with_fr_due_by
    email_config = fetch_email_config
    params = ticket_params_hash.except(:source, :status, :due_by, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({ _action: 'compose_email' }, params)
    assert_response 400
    match_json([bad_request_error_pattern('fr_due_by',  :cannot_set_due_by_fields, code: :incompatible_field)])
  end

  def test_compose_email_without_status_with_due_by
    email_config = fetch_email_config
    params = ticket_params_hash.except(:source, :status, :fr_due_by, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({ _action: 'compose_email' }, params)
    assert_response 400
    match_json([bad_request_error_pattern('due_by',  :cannot_set_due_by_fields, code: :incompatible_field)])
  end

  def test_compose_email_without_mandatory_params
    params = ticket_params_hash.except(:source, :product_id, :responder_id, :email, :subject).merge(custom_fields: {})
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({ _action: 'compose_email' }, params)
    assert_response 400
    match_json([bad_request_error_pattern('email_config_id',  :field_validation_for_outbound, code: :missing_field),
                bad_request_error_pattern('subject',  :field_validation_for_outbound, code: :missing_field),
                bad_request_error_pattern('email',  :field_validation_for_outbound, code: :missing_field)])
  end

  def test_compose_email_with_invalid_email_config_id
    params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {}, email_config_id: Account.current.email_configs.last.id + 200)
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({ _action: 'compose_email' }, params)
    assert_response 400
    match_json([bad_request_error_pattern('email_config_id',  :absent_in_db, resource: :email_config, attribute: :email_config_id)])
  end

  def test_compose_email_with_group_ticket_permission_valid
    Account.any_instance.stubs(:restricted_compose_enabled?).returns(:true)
    User.any_instance.stubs(:can_view_all_tickets?).returns(false)
    User.any_instance.stubs(:group_ticket_permission).returns(true)
    email_config = create_email_config(group_id: ticket_params_hash[:group_id])
    params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({ _action: 'compose_email' }, params)
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
  ensure
    Account.any_instance.unstub(:restricted_compose_enabled?)
    User.any_instance.unstub(:can_view_all_tickets?)
    User.any_instance.unstub(:group_ticket_permission)
  end

  def test_compose_email_with_group_ticket_permission_invalid
    Account.any_instance.stubs(:restricted_compose_enabled?).returns(:true)
    User.any_instance.stubs(:can_view_all_tickets?).returns(false)
    User.any_instance.stubs(:group_ticket_permission).returns(true)
    email_config = create_email_config(group_id: create_group(@account).id)
    params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({ _action: 'compose_email' }, params)
    assert_response 400
    match_json([bad_request_error_pattern('email_config_id',  :inaccessible_value, resource: :email_config, attribute: :email_config_id)])
  ensure
    Account.any_instance.unstub(:restricted_compose_enabled?)
    User.any_instance.unstub(:can_view_all_tickets?)
    User.any_instance.unstub(:group_ticket_permission)
  end

  def test_compose_email_with_assign_ticket_permission_valid
    Account.any_instance.stubs(:restricted_compose_enabled?).returns(:true)
    User.any_instance.stubs(:can_view_all_tickets?).returns(false)
    User.any_instance.stubs(:group_ticket_permission).returns(false)
    User.any_instance.stubs(:assigned_ticket_permission).returns(true)
    email_config = create_email_config
    params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({ _action: 'compose_email' }, params)
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
  ensure
    Account.any_instance.unstub(:restricted_compose_enabled?)
    User.any_instance.unstub(:can_view_all_tickets?)
    User.any_instance.unstub(:group_ticket_permission)
    User.any_instance.unstub(:assigned_ticket_permission)
  end

  def test_compose_email_with_assign_ticket_permission_invalid
    Account.any_instance.stubs(:restricted_compose_enabled?).returns(:true)
    User.any_instance.stubs(:can_view_all_tickets?).returns(false)
    User.any_instance.stubs(:group_ticket_permission).returns(false)
    User.any_instance.stubs(:assigned_ticket_permission).returns(true)
    email_config = create_email_config(group_id: create_group(@account).id)
    params = ticket_params_hash.except(:source, :product_id, :responder_id).merge(custom_fields: {}, email_config_id: email_config.id)
    CUSTOM_FIELDS.each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({ _action: 'compose_email' }, params)
    assert_response 400
    match_json([bad_request_error_pattern('email_config_id',  :inaccessible_value, resource: :email_config, attribute: :email_config_id)])
  ensure
    Account.any_instance.unstub(:restricted_compose_enabled?)
    User.any_instance.unstub(:can_view_all_tickets?)
    User.any_instance.unstub(:group_ticket_permission)
    User.any_instance.unstub(:assigned_ticket_permission)
  end

  def test_update_compose_email_with_subject_and_description
    Account.any_instance.stubs(:compose_email_enabled?).returns(true)
    t = ticket
    t.update_attributes(source: 10, email_config_id: fetch_email_config.id)
    params_hash = update_ticket_params_hash.except(:email, :source).merge(subject: Faker::Lorem.paragraph, description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('subject', :outbound_email_field_restriction, code: :incompatible_field),
                bad_request_error_pattern('description', :outbound_email_field_restriction, code: :incompatible_field)])
  ensure
    Account.any_instance.unstub(:compose_email_enabled?)
  end

  def test_update_compose_email_without_email_config_id
    Account.any_instance.stubs(:compose_email_enabled?).returns(true)
    t = ticket
    t.update_attributes(source: 10)
    params_hash = update_ticket_params_hash.except(:email, :source, :subject, :description).merge(type: 'Problem')
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 200
  ensure
    Account.any_instance.unstub(:compose_email_enabled?)
  end

  def test_update_with_subject_and_description_source_outbound_email
    Account.any_instance.stubs(:compose_email_enabled?).returns(true)
    t = ticket
    ticket.update_attribute(:email_config_id, fetch_email_config.id)
    params_hash = update_ticket_params_hash.except(:email).merge(source: 10, subject: Faker::Lorem.paragraph, description: Faker::Lorem.paragraph)
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('subject', :outbound_email_field_restriction, code: :incompatible_field),
                bad_request_error_pattern('description', :outbound_email_field_restriction, code: :incompatible_field)])
  ensure
    Account.any_instance.unstub(:compose_email_enabled?)
  end

  def test_update_with_source_as_outbound_email_invalid
    Account.any_instance.stubs(:compose_email_enabled?).returns(false)
    t = ticket
    params_hash = update_ticket_params_hash.except(:email).merge(source: 100)
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('source', :not_included, list: '1,2,3,5,6,7,8,9,11,12')])
  ensure
    Account.any_instance.unstub(:compose_email_enabled?)
  end

  def test_update_outbound_email_with_responder_id_and_product_valid
    Account.any_instance.stubs(:compose_email_enabled?).returns(true)
    t = ticket
    t.update_attributes(source: 10)
    product_id = create_product.id
    params_hash = update_ticket_params_hash.except(:email, :source, :subject, :description).merge(product_id: product_id)
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json(update_ticket_pattern(params_hash, t.reload))
    match_json(update_ticket_pattern({}, t.reload))
    assert_response 200
  ensure
    Account.any_instance.unstub(:compose_email_enabled?)
  end

  def test_update_outbound_email_with_responder_id_and_product_invalid
    Account.any_instance.stubs(:compose_email_enabled?).returns(true)
    t = ticket
    t.update_attributes(source: 10)
    product_id = create_product.id
    params_hash = update_ticket_params_hash.except(:email, :source, :subject, :description).merge(product_id: 'test', responder_id: 'thj')
    put :update, construct_params({ id: t.display_id }, params_hash)
    match_json([bad_request_error_pattern('responder_id', :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: String, prepend_msg: :input_received),
                bad_request_error_pattern('product_id', :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: String, prepend_msg: :input_received)])
    assert_response 400
  ensure
    Account.any_instance.unstub(:compose_email_enabled?)
  end

  def test_update_with_source_as_outbound_email_valid
    Account.any_instance.stubs(:compose_email_enabled?).returns(true)
    t = ticket
    ticket.update_attributes(email_config_id: fetch_email_config.id)
    params_hash = update_ticket_params_hash.except(:email, :subject, :description).merge(source: 10)
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 200
  ensure
    Account.any_instance.unstub(:compose_email_enabled?)
  end

  def test_create_with_section_fields
    sections = construct_sections('type')
    create_section_fields(3, sections)
    params = ticket_params_hash.merge(custom_fields: {}, type: 'Incident', description: '<b>test</b>')
    ['paragraph', 'dropdown'].each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({}, params)
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    result = parse_response(@response.body)
    assert_equal true, response.headers.include?('Location')
    assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
    assert_response 201
    assert_equal '<b>test</b>', Helpdesk::Ticket.last.description_html
    assert_equal 'test', Helpdesk::Ticket.last.description
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
  end

  def test_create_with_section_fields_with_custom_dropdown_parent
    dd_field_id = create_custom_field_dropdown_with_sections.id
    sections = construct_sections('test_custom_dropdown')
    create_section_fields(dd_field_id, sections);
    params = ticket_params_hash.merge(custom_fields: {section_custom_dropdown: 'Choice 3'}, description: '<b>test</b>')
    ['paragraph'].each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({}, params)
    match_json(ticket_pattern(params, Helpdesk::Ticket.last))
    match_json(ticket_pattern({}, Helpdesk::Ticket.last))
    result = parse_response(@response.body)
    assert_equal true, response.headers.include?('Location')
    assert_equal "http://#{@request.host}/api/v2/tickets/#{result['id']}", response.headers['Location']
    assert_response 201
    assert_equal '<b>test</b>', Helpdesk::Ticket.last.description_html
    assert_equal 'test', Helpdesk::Ticket.last.description
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
  end

  def test_create_with_section_fields_absence_check_error_with_format_validatable_fields
    create_section_fields
    params = ticket_params_hash.merge(custom_fields: {}, type: 'Feature Request', description: '<b>test</b>')
    ['number', 'date'].each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({}, params)
    assert_response 201
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
  end

  def test_create_with_section_fields_absence_check_error_with_choices_fields
    create_section_fields
    params = ticket_params_hash.merge(custom_fields: {}, type: 'Feature Request', description: '<b>test</b>')
    ['dropdown'].each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    post :create, construct_params({}, params)
    assert_response 201
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
  end

  def test_update_with_section_fields_ticket_type_parent
    sections = construct_sections('type')
    create_section_fields(3, sections)
    t = create_ticket(ticket_params_hash)
    params = update_ticket_params_hash.except(:description).merge(custom_fields: {}, type: 'Incident')
    ['paragraph', 'dropdown'].each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    Sidekiq::Testing.inline! do
      put :update, construct_params({ id: t.display_id }, params)
    end
    match_json(ticket_pattern(params, t.reload))
    assert_response 200
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
  end

  def test_update_with_section_fields_with_custom_dropdown_parent
    dd_field_id = create_custom_field_dropdown_with_sections.id
    sections = construct_sections('section_custom_dropdown')
    create_section_fields(dd_field_id, sections);
    t = create_ticket(ticket_params_hash)
    params = update_ticket_params_hash.except(:description).merge(custom_fields: {section_custom_dropdown: 'Choice 3'})
    ['paragraph'].each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    Sidekiq::Testing.inline! do
      put :update, construct_params({ id: t.display_id }, params)
    end
    match_json(ticket_pattern(params, t.reload))
    assert_response 200
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
  end

  def test_update_with_nested_field_with_first_level
    params = ticket_params_hash.merge(custom_field: {})
    ['country', 'state', 'city'].each do |custom_field|
      params[:custom_field]["test_custom_#{custom_field}_#{@account.id}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    t = create_ticket(params)
    update_params = update_ticket_params_hash.merge(custom_fields: {})
    update_params[:custom_fields][:test_custom_country] = UPDATE_CUSTOM_FIELDS_VALUES['country']
    Sidekiq::Testing.inline! do
      put :update, construct_params({ id: t.display_id }, update_params)
    end
    response = parse_response @response.body
    assert_response 200
    assert_equal response['custom_fields']['test_custom_country'], 'Australia'
    assert_nil response['custom_fields']['test_custom_state']
    assert_nil response['custom_fields']['test_custom_city']
  end

  def test_update_with_nested_field_with_second_level
    params = ticket_params_hash.merge(custom_field: {})
    ['country', 'state', 'city'].each do |custom_field|
      params[:custom_field]["test_custom_#{custom_field}_#{@account.id}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    t = create_ticket(params)
    update_params = update_ticket_params_hash.merge(custom_fields: {})
    update_params[:custom_fields][:test_custom_state] = UPDATE_NESTED_FIELD_VALUES['state']
    Sidekiq::Testing.inline! do
      put :update, construct_params({ id: t.display_id }, update_params)
    end
    response = parse_response @response.body
    assert_response 200
    assert_equal response['custom_fields']['test_custom_country'], 'USA'
    assert_equal response['custom_fields']['test_custom_state'], 'Texas'
    assert_nil response['custom_fields']['test_custom_city']
  end

  def test_update_with_nested_field_with_first_two_levels
    params = ticket_params_hash.merge(custom_field: {})
    ['country', 'state', 'city'].each do |custom_field|
      params[:custom_field]["test_custom_#{custom_field}_#{@account.id}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    t = create_ticket(params)
    update_params = update_ticket_params_hash.merge(custom_fields: {})
    ['country', 'state'].each do |custom_field|
      update_params[:custom_fields]["test_custom_#{custom_field}"] = UPDATE_CUSTOM_FIELDS_VALUES[custom_field]
    end
    Sidekiq::Testing.inline! do
      put :update, construct_params({ id: t.display_id }, update_params)
    end
    response = parse_response @response.body
    assert_response 200
    assert_equal response['custom_fields']['test_custom_country'], 'Australia'
    assert_equal response['custom_fields']['test_custom_state'], 'Queensland'
    assert_nil response['custom_fields']['test_custom_city']
  end

  def test_update_with_section_fields_absence_check_error_with_format_validatable_fields
    create_section_fields
    params = update_ticket_params_hash.merge(custom_fields: {}, type: 'Feature Request', description: '<b>test</b>')
    ['number', 'date'].each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    t = ticket
    put :update, construct_params({ id: t.display_id }, params)
    match_json(ticket_pattern(params, t.reload))
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
  end

  def test_update_with_section_fields_absence_check_error_with_choices_fields
    create_section_fields
    params = update_ticket_params_hash.merge(custom_fields: {}, type: 'Feature Request', description: '<b>test</b>')
    ['dropdown'].each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    t = ticket
    put :update, construct_params({ id: t.display_id }, params)
    match_json(ticket_pattern(params, t.reload))
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
  end

  def test_update_with_section_fields_with_custom_dropdown_parent_with_remove_fields_feature
    @account.launch(:remove_unrelated_fields)
    dd_field_id = create_custom_field_dropdown_with_sections.id
    sections = construct_sections('section_custom_dropdown')
    create_section_fields(dd_field_id, sections);
    t = create_ticket(ticket_params_hash)
    params = update_ticket_params_hash.except(:description).merge(custom_fields: {section_custom_dropdown: 'Choice 3'})
    ['paragraph'].each do |custom_field|
      params[:custom_fields]["test_custom_#{custom_field}"] = CUSTOM_FIELDS_VALUES[custom_field]
    end
    Sidekiq::Testing.inline! do
      put :update, construct_params({ id: t.display_id }, params)
    end
    params[:custom_fields]['test_custom_paragraph'] = nil # expected_saved_params ; test_custom_paragraph will be ignored
    match_json(ticket_pattern(params, t.reload))
    assert_response 200
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
    @account.rollback(:remove_unrelated_fields)
  end

  def test_create_with_section_fields_without_format_required_fields
    create_section_fields
    params = ticket_params_hash.merge(custom_fields: {}, type: 'Problem', description: '<b>test</b>')
    Helpdesk::TicketField.where(name: "test_custom_number_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    Helpdesk::TicketField.where(name: "test_custom_number_#{@account.id}").update_all(required: false)
    pattern = []
    ['number'].each do |custom_field|
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
    assert_response 400
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
  end

  def test_create_with_section_fields_without_choices_required_fields
    create_section_fields
    params = ticket_params_hash.merge(custom_fields: {}, type: 'Incident', description: '<b>test</b>')
    Helpdesk::TicketField.where(name: "test_custom_dropdown_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    Helpdesk::TicketField.where(name: "test_custom_dropdown_#{@account.id}").update_all(required: false)
    pattern = []
    ['dropdown'].each do |custom_field|
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_CHOICES_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
    assert_response 400
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
  end

  def test_update_with_section_fields_without_format_required_fields
    create_section_fields
    t = create_ticket(ticket_params_hash)
    params_hash = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 5, type: 'Incident')
    Helpdesk::TicketField.where(name: "test_custom_paragraph_#{@account.id}").update_all(required_for_closure: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: "test_custom_paragraph_#{@account.id}").update_all(required_for_closure: false)
    pattern = []
    ['paragraph'].each do |custom_field|
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
    assert_response 400
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
  end

  def test_update_with_section_fields_without_choices_required_fields
    create_section_fields
    t = create_ticket(ticket_params_hash)
    params_hash = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 5, type: 'Incident')
    Helpdesk::TicketField.where(name: "test_custom_dropdown_#{@account.id}").update_all(required_for_closure: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: "test_custom_dropdown_#{@account.id}").update_all(required_for_closure: false)
    pattern = []
    ['dropdown'].each do |custom_field|
      pattern << bad_request_error_pattern(custom_field_error_label("test_custom_#{custom_field}"), *(ERROR_CHOICES_REQUIRED_PARAMS[custom_field]))
    end
    match_json(pattern)
    assert_response 400
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
  end

  def test_create_with_section_fields_without_format_required_fields_valid
    create_section_fields
    params = ticket_params_hash.merge(custom_fields: {}, type: 'Incident', description: '<b>test</b>')
    Helpdesk::TicketField.where(name: "test_custom_number_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    Helpdesk::TicketField.where(name: "test_custom_number_#{@account.id}").update_all(required: false)
    assert_response 201
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
  end

  def test_create_with_section_fields_without_choices_required_fields_valid
    create_section_fields
    params = ticket_params_hash.merge(custom_fields: {}, type: 'Problem', description: '<b>test</b>')
    Helpdesk::TicketField.where(name: "test_custom_dropdown_#{@account.id}").update_all(required: true)
    post :create, construct_params({}, params)
    Helpdesk::TicketField.where(name: "test_custom_dropdown_#{@account.id}").update_all(required: false)
    assert_response 201
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
  end

  def test_update_with_section_fields_without_format_required_fields_valid
    create_section_fields
    t = create_ticket(ticket_params_hash)
    params_hash = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 5, type: 'Problem')
    Helpdesk::TicketField.where(name: "test_custom_paragraph_#{@account.id}").update_all(required_for_closure: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: "custom_fields.test_custom_paragraph_#{@account.id}").update_all(required_for_closure: false)
    assert_response 200
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
  end

  def test_update_with_section_fields_without_choices_required_fields_valid
    create_section_fields
    t = create_ticket(ticket_params_hash)
    params_hash = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 5, type: 'Problem')
    Helpdesk::TicketField.where(name: "test_custom_dropdown_#{@account.id}").update_all(required_for_closure: true)
    put :update, construct_params({ id: t.display_id }, params_hash)
    Helpdesk::TicketField.where(name: "test_custom_dropdown_#{@account.id}").update_all(required_for_closure: false)
    assert_response 200
  ensure
    @account.ticket_fields.custom_fields.each do |x|
      x.update_attributes(field_options: nil) if %w(number date dropdown paragraph).any? { |b| x.name.include?(b) }
    end
  end

  # Multiple Companies Feature

  def test_create_without_company_id
    sample_requester = get_user_with_default_company
    params = {
        requester_id: sample_requester.id,
        status: 2, priority: 2,
        subject: Faker::Name.name, description: Faker::Lorem.paragraph
    }
    post :create, construct_params({}, params)
    t = Helpdesk::Ticket.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_equal t.owner_id, sample_requester.company_id
    assert_response 201
  end

  def test_create_with_unique_external_id_and_expect_validation_error
    params = {
        subject: Faker::Lorem.characters(100),
        description: Faker::Lorem.paragraph,
        unique_external_id: Faker::Lorem.characters(30),
        status: 2, priority: 2,
    }
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(
                    'unique_external_id', :require_feature_for_attribute,
                    code: :inaccessible_field, feature: :unique_contact_identifier,
                    attribute: "unique_external_id")]
    )
  end

  def test_create_with_integer_unique_external_id_and_expect_validation_error
    @account.add_feature :unique_contact_identifier
    params = {
        email: "bob1.tree@freshdesk.com",
        name: "Native",
        subject: Faker::Lorem.characters(100),
        description: Faker::Lorem.paragraph,
        unique_external_id: 1,
        phone:"720 428-8050",
        status: 2, priority: 2,
    }
    post :create, construct_params({}, params)
    assert_response 400
    results = parse_response(@response.body)
    assert_equal results, {"description"=>"Validation failed", "errors"=> [{"field"=>"unique_external_id",
                                                                            "message"=>"Value set is of type Integer.It should be a/an String",
                                                                            "code"=>"datatype_mismatch"}]}
    @account.revoke_feature :unique_contact_identifier
  end

  def test_create_with_unique_external_id
    params = {
        subject: Faker::Lorem.characters(100),
        description: Faker::Lorem.paragraph,
        unique_external_id: Faker::Lorem.characters(30),
        status: 2, priority: 2,
    }
    @account.add_feature :unique_contact_identifier
    post :create, construct_params({}, params)
    assert_response 201
    results = parse_response(@response.body)
    assert_not_nil results['id']
    @account.revoke_feature :unique_contact_identifier
  end

  def test_create_meta_note_publish
    CentralPublishWorker::ActiveNoteWorker.jobs.clear
    CentralPublishWorker::TrialNoteWorker.jobs.clear
    Account.any_instance.stubs(:note_central_publish_enabled?).returns(true)
    sample_requester = get_user_with_default_company
    params = {
      requester_id: sample_requester.id,
      status: 2, priority: 2,
      subject: Faker::Name.name, description: Faker::Lorem.paragraph
    }
    post :create, construct_params({}, params)
    assert_response 201
    assert_equal 0, CentralPublishWorker::ActiveNoteWorker.jobs.size
    assert_equal 0, CentralPublishWorker::TrialNoteWorker.jobs.size
  ensure
    Account.any_instance.unstub(:note_central_publish_enabled?)
  end

  def test_update_with_new_unique_external_id
    @account.add_feature :unique_contact_identifier
    params_hash = { unique_external_id: Faker::Lorem.characters(20) }
    t = ticket
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 200
    results = parse_response(@response.body)
    assert_not_equal results['requester_id'], t.requester_id
    @account.reload
    @account.revoke_feature :unique_contact_identifier
  end

  def test_create_with_company_id
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
    company = get_company
    sample_requester = requester
    sample_requester.company_id = company.id
    sample_requester.save!
    params = {
        requester_id: sample_requester.id,
        company_id: company.id, status: 2,
        priority: 2, subject: Faker::Name.name,
        description: Faker::Lorem.paragraph
    }
    post :create, construct_params({}, params)
    t = Helpdesk::Ticket.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_equal t.owner_id, company.id
    assert_response 201
  ensure
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
  end

  def test_create_with_other_company_id_of_requester
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
    sample_requester = get_user_with_multiple_companies
    company_id = (sample_requester.company_ids - [sample_requester.company_id]).sample
    params = {
        requester_id: sample_requester.id,
        company_id: company_id, status: 2,
        priority: 2, subject: Faker::Name.name,
        description: Faker::Lorem.paragraph
    }
    post :create, construct_params({}, params)
    t = Helpdesk::Ticket.last
    match_json(ticket_pattern(params, t))
    match_json(ticket_pattern({}, t))
    assert_equal t.owner_id, company_id
    assert_response 201
  ensure
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
  end

  def test_create_with_unavailable_company_id
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
    company_id = 15_000
    params = {
        requester_id: requester.id, company_id: company_id,
        status: 2, priority: 2, subject: Faker::Name.name,
        description: Faker::Lorem.paragraph
    }
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(
                    'company_id', :invalid_company_id, company_id: 15_000, attribute: :company_id)]
    )
  ensure
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
  end

  def test_create_with_string_company_id
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
    company_id = "str"
    params = { requester_id: requester.id, company_id: company_id,
               status: 2, priority: 2, subject: Faker::Name.name,
               description: Faker::Lorem.paragraph
    }
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(
                    'company_id', :datatype_mismatch, code: :missing_field,
                    expected_data_type: 'Positive Integer', prepend_msg: :input_received,
                    given_data_type: 'String')]
    )
  ensure
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
  end

  def test_create_with_boolean_company_id
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
    company_id = true
    params = {
        requester_id: requester.id, company_id: company_id,
        status: 2, priority: 2, subject: Faker::Name.name,
        description: Faker::Lorem.paragraph
    }
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(
                    'company_id', :datatype_mismatch, code: :missing_field,
                    expected_data_type: 'Positive Integer', prepend_msg: :input_received,
                    given_data_type: 'Boolean')]
    )
  ensure
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
  end

  def test_create_with_negative_company_id
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
    company_id = -100
    params = {
        requester_id: requester.id, company_id: company_id,
        status: 2, priority: 2, subject: Faker::Name.name,
        description: Faker::Lorem.paragraph
    }
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(
                    'company_id', :datatype_mismatch, code: :missing_field,
                    expected_data_type: 'Positive Integer')]
    )
  ensure
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
  end

  def test_create_with_company_id_without_multiple_user_companies_feature
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(false)
    company = get_company
    sample_requester = requester
    sample_requester.company_id = company.id
    sample_requester.save!
    params = {
        requester_id: sample_requester.id, company_id: company.id,
        status: 2, priority: 2, subject: Faker::Name.name,
        description: Faker::Lorem.paragraph
    }
    post :create, construct_params({}, params)
    assert_response 400
    match_json([bad_request_error_pattern(
                    'company_id', :require_feature_for_attribute, {
                    code: :inaccessible_field,
                    feature: :multiple_user_companies,
                    attribute: "company_id" })]
    )
  ensure
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
  end

  def test_update_with_company_id
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
    t = ticket
    sample_requester = get_user_with_multiple_companies
    t.update_attributes(:requester => sample_requester)
    company_id = sample_requester.user_companies.where(:default => false).first.company.id
    params = { company_id: company_id }
    put :update, construct_params({ id: t.display_id }, params)
    t.reload
    assert t.owner_id == company_id
    match_json(update_ticket_pattern(params, t))
    match_json(update_ticket_pattern({}, t))
    assert_response 200
  ensure
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
  end

  def test_update_with_unavailable_company_id
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
    t = ticket
    company_id = 90_000
    params = { company_id: company_id }
    put :update, construct_params({ id: t.display_id }, params)
    assert t.owner_id != company_id
    assert_response 400
    match_json([bad_request_error_pattern(
                    'company_id', :invalid_company_id, company_id: 90_000,
                    attribute: :company_id)]
    )
  ensure
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
  end

  def test_update_with_string_company_id
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
    t = ticket
    company_id = "str"
    params = { company_id: company_id }
    put :update, construct_params({ id: t.display_id }, params)
    assert t.owner_id != company_id
    assert_response 400
    match_json([bad_request_error_pattern(
                    'company_id', :datatype_mismatch,
                    code: :missing_field, expected_data_type: 'Positive Integer',
                    prepend_msg: :input_received, given_data_type: String)]
    )
  ensure
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
  end

  def test_update_with_boolean_company_id
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
    t = ticket
    company_id = false
    params = { company_id: company_id }
    put :update, construct_params({ id: t.display_id }, params)
    assert t.owner_id != company_id
    assert_response 400
    match_json([bad_request_error_pattern(
                    'company_id', :datatype_mismatch, code: :missing_field,
                    expected_data_type: 'Positive Integer', prepend_msg: :input_received,
                    given_data_type: 'Boolean')]
    )
  ensure
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
  end

  def test_update_with_negative_company_id
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(true)
    t = ticket
    company_id = -109
    params = { company_id: company_id }
    put :update, construct_params({ id: t.display_id }, params)
    assert t.owner_id != company_id
    assert_response 400
    match_json([bad_request_error_pattern(
                    'company_id', :datatype_mismatch,
                    code: :missing_field, expected_data_type: 'Positive Integer')]
    )
  ensure
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
  end

  def test_update_with_company_id_without_multiple_user_companies_feature
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(false)
    t = ticket
    company_id = 1
    params = { company_id: company_id }
    put :update, construct_params({ id: t.display_id }, params)
    assert_response 400
    match_json([bad_request_error_pattern(
                    'company_id', :require_feature_for_attribute, {
                    code: :inaccessible_field, feature: :multiple_user_companies,
                    attribute: "company_id"
                })]
    )
  ensure
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
  end

  def test_update_with_private_api_params
    t = ticket
    params_hash = update_ticket_params_hash.except(:fr_due_by, :due_by).merge(status: 5, skip_close_notification: true) # skip_close_notification available only in private api
    delayed_job_count_before = Delayed::Job.count
    put :update, construct_params({ id: t.display_id }, params_hash)
    assert_response 200
    match_json(update_ticket_pattern(params_hash, t.reload))
    match_json(update_ticket_pattern({}, t))
    assert_equal delayed_job_count_before + 1, Delayed::Job.count
  end

  def test_update_when_subject_is_blank
    t = create_ticket(requester_id: @agent.id)
    Helpdesk::Ticket.any_instance.stubs(:subject).returns("")
    put :update, construct_params({ id: ticket.display_id }, {priority: 4})
    assert_response 200
  ensure
    Helpdesk::Ticket.any_instance.unstub(:subject)
  end

  def test_create_child
    enable_adv_ticketing([:parent_child_tickets]) do
      Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
      parent_ticket = create_ticket
      params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
      post :create, construct_params(params_hash)
      assert_response 201
      latest_ticket = Account.current.tickets.last
      match_json(ticket_pattern(latest_ticket).merge!(ticket_association_pattern(latest_ticket)))
      parent_ticket.reload
      assert_equal nil, latest_ticket.subsidiary_tkts_count
      assert_equal 1, parent_ticket.subsidiary_tkts_count
    end
  end

  def test_create_child_with_existing_parent
    enable_adv_ticketing([:parent_child_tickets]) do
      parent_ticket = create_parent_ticket
      Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
      Helpdesk::Ticket.any_instance.stubs(:associates).returns([1])
      params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
      post :create, construct_params(params_hash)
      assert_response 201
      latest_ticket = Account.current.tickets.last
      match_json(ticket_pattern(latest_ticket).merge!(ticket_association_pattern(latest_ticket)))
      assert_equal nil, latest_ticket.subsidiary_tkts_count
      assert_equal 1, parent_ticket.subsidiary_tkts_count
    end
  ensure
    Helpdesk::Ticket.any_instance.unstub(:associates=)
    Helpdesk::Ticket.any_instance.unstub(:associates)
  end

  def test_destroy_child_ticket
    enable_adv_ticketing([:parent_child_tickets]) do
      create_parent_child_tickets
      @child_ticket.update_column(:deleted, false)
      sidekiq_inline {
        delete :destroy, construct_params(id: @child_ticket.display_id)
      }
      assert_response 204
      assert Helpdesk::Ticket.find_by_display_id(@child_ticket.display_id).deleted == true
      parent_ticket = Helpdesk::Ticket.find_by_display_id(@parent_ticket.display_id)
      assert_equal nil, parent_ticket.association_type
      assert_equal nil, parent_ticket.subsidiary_tkts_count
    end
  end

  def test_destroy_parent_ticket
    enable_adv_ticketing([:parent_child_tickets]) do
      create_parent_child_tickets
      @parent_ticket.update_column(:deleted, false)
      sidekiq_inline { delete :destroy, construct_params(id: @parent_ticket.display_id) }
      assert_response 204
      assert Helpdesk::Ticket.find_by_display_id(@parent_ticket.display_id).deleted == true
      parent_ticket = Helpdesk::Ticket.find_by_display_id(@parent_ticket.display_id)
      assert_equal nil, parent_ticket.association_type
      assert_equal nil, parent_ticket.subsidiary_tkts_count
      child_ticket = Helpdesk::Ticket.find_by_display_id(@parent_ticket.display_id)
      assert_equal nil, child_ticket.association_type
    end
  end

  def test_create_child_without_feature
    disable_adv_ticketing([:parent_child_tickets, :field_service_management, :parent_child_infra])
    parent_ticket = create_parent_ticket
    params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('parent_id', :require_feature_for_attribute,
                                          code: :inaccessible_field, feature: :parent_child_infra, attribute: 'parent_id')])
  end

  def test_create_child_to_inaccessible_parent
    enable_adv_ticketing([:parent_child_tickets]) do
      Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
      parent_ticket = create_parent_ticket
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
      post :create, construct_params(params_hash)
      assert_response 403
    end
  ensure
    Helpdesk::Ticket.any_instance.unstub(:associates=)
    User.any_instance.unstub(:has_ticket_permission?)
  end

  def test_create_child_to_parent_with_max_children
    enable_adv_ticketing([:parent_child_tickets]) do
      Helpdesk::Ticket.any_instance.stubs(:associates).returns((10..21).to_a)
      parent_ticket = create_parent_ticket
      params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
      post :create, construct_params(params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('parent_id', :exceeds_limit, limit: TicketConstants::CHILD_TICKETS_PER_ASSOC_PARENT)])
    end
  ensure
    Helpdesk::Ticket.any_instance.unstub(:associates)
  end

  def test_create_child_to_a_spam_parent
    enable_adv_ticketing([:parent_child_tickets]) do
      parent_ticket = create_parent_ticket
      parent_ticket.update_attributes(spam: true)
      params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
      post :create, construct_params(params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('parent_id', :invalid_parent)])
      parent_ticket.update_attributes(spam: false)
    end
  end

  def test_create_child_to_a_invalid_parent
    enable_adv_ticketing([:parent_child_tickets]) do
      parent_ticket = create_parent_ticket
      parent_ticket.update_attributes(association_type: 4) # Related
      params_hash = ticket_params_hash.merge(parent_id: parent_ticket.display_id)
      post :create, construct_params(params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('parent_id', :invalid_parent)])
    end
  end

  def test_create_child_with_parent_attachments
    enable_adv_ticketing([:parent_child_tickets]) do
      parent = create_ticket_with_attachments
      params = ticket_params_hash.merge(parent_id: parent.display_id, attachment_ids: parent.attachments.map(&:id))
      stub_attachment_to_io do
        post :create, construct_params(params)
      end
      child = Account.current.tickets.last
      match_json(ticket_pattern(child).merge!(ticket_association_pattern(child)))
      assert child.attachments.size == parent.attachments.size
    end
  end

  def test_create_child_with_some_parent_attachments
    enable_adv_ticketing([:parent_child_tickets]) do
      parent = create_ticket_with_attachments(1, 5)
      params = ticket_params_hash.merge(parent_id: parent.display_id, attachment_ids: parent.attachments.map(&:id).first(1))
      stub_attachment_to_io do
        post :create, construct_params(params)
      end
      child = Account.current.tickets.last
      match_json(ticket_pattern(child).merge!(ticket_association_pattern(child)))
      assert child.attachments.count == 1
    end
  end

  def test_create_child_with_some_parent_attachments_some_new_attachments
    enable_adv_ticketing([:parent_child_tickets]) do
      parent = create_ticket_with_attachments(1, 5)
      parent_attachment_ids = parent.attachments.map(&:id).first(1)
      child_attachment_ids = []
      child_attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params = ticket_params_hash.merge(parent_id: parent.display_id, attachment_ids: parent_attachment_ids + child_attachment_ids)
      stub_attachment_to_io do
        post :create, construct_params(params)
      end
      child = Account.current.tickets.last
      match_json(ticket_pattern(child).merge!(ticket_association_pattern(child)))
      assert child.attachments.count == 2
    end
  end

  def test_create_child_with_no_parent_attachments_only_new_attachments
    enable_adv_ticketing([:parent_child_tickets]) do
      parent = create_ticket_with_attachments
      child_attachment_ids = []
      child_attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params = ticket_params_hash.merge(parent_id: parent.display_id, attachment_ids: child_attachment_ids)
      stub_attachment_to_io do
        post :create, construct_params(params)
      end
      child = Account.current.tickets.last
      match_json(ticket_pattern(child).merge!(ticket_association_pattern(child)))
      assert child.attachments.count == 1
    end
  end

  def test_tracker_create
    enable_adv_ticketing([:link_tickets]) do
      Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
      create_ticket
      agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      ticket = Helpdesk::Ticket.last
      params_hash = ticket_params_hash.merge(email: agent.email, related_ticket_ids: [ticket.display_id])
      post :create, construct_params(params_hash)
      assert_response 201
      latest_ticket = Helpdesk::Ticket.last
      ticket.reload
      match_json(ticket_pattern(latest_ticket).merge!(ticket_association_pattern(latest_ticket)))
      assert ticket.related_ticket?
      assert_equal nil, ticket.subsidiary_tkts_count
      assert latest_ticket.tracker_ticket?
      assert_equal 1, latest_ticket.subsidiary_tkts_count
    end
  ensure
    Helpdesk::Ticket.any_instance.unstub(:associates=)
  end

  def test_destroy_related_ticket
    enable_adv_ticketing([:link_tickets]) do
      create_linked_tickets
      sidekiq_inline { delete :destroy, construct_params(id: @ticket_id) }
      assert_response 204
      assert Helpdesk::Ticket.find_by_display_id(@ticket_id).deleted == true
      tracker_ticket = Helpdesk::Ticket.find_by_display_id(@tracker_id)
      assert_equal 3, tracker_ticket.association_type
      assert_equal 0, tracker_ticket.subsidiary_tkts_count
      related_ticket = Helpdesk::Ticket.find_by_display_id(@ticket_id)
      assert_equal nil, related_ticket.association_type
      assert_equal nil, related_ticket.subsidiary_tkts_count
    end
  end

  def test_tracker_create_with_contact_email
    enable_adv_ticketing([:link_tickets]) do
      create_ticket
      ticket = Helpdesk::Ticket.last
      params_hash = ticket_params_hash.merge(related_ticket_ids: [ticket.display_id])
      post :create, construct_params(params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('email', nil, append_msg: I18n.t('ticket.tracker_agent_error'))])
      assert !ticket.related_ticket?
    end
  end

  def test_tracker_create_without_feature
    Account.any_instance.stubs(:link_tkts_enabled?).returns(false)
    create_ticket
    ticket = Helpdesk::Ticket.last
    params_hash = ticket_params_hash.merge(related_ticket_ids: [ticket.display_id])
    post :create, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('related_ticket_ids', :require_feature_for_attribute,
                                          code: :inaccessible_field, feature: :link_tickets, attribute: 'related_ticket_ids')])
  ensure
    Account.any_instance.unstub(:link_tkts_enabled?)
  end

  def test_tracker_create_with_invalid_params
    enable_adv_ticketing([:link_tickets]) do
      create_ticket
      ticket = Helpdesk::Ticket.last
      params_hash = ticket_params_hash.merge(related_ticket_ids: ticket.display_id)
      post :create, construct_params(params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('related_ticket_ids', :datatype_mismatch, prepend_msg: :input_received, expected_data_type: 'Array', given_data_type: 'Integer')])
    end
  end

  def test_tracker_create_with_max_related_tickets
    enable_adv_ticketing([:link_tickets]) do
      related_ticket_ids = (1..301).to_a
      params_hash = ticket_params_hash.merge(related_ticket_ids: related_ticket_ids)
      post :create, construct_params(params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('related_ticket_ids', nil, append_msg: :too_long, element_type: :values, max_count: TicketConstants::MAX_RELATED_TICKETS, current_count: 301)])
    end
  end

  def test_tracker_create_with_all_invalid_related_tickets
    enable_adv_ticketing([:link_tickets]) do
      tickets = create_related_tickets(2)
      params_hash = ticket_params_hash.merge(related_ticket_ids: tickets.map(&:display_id))
      post :create, construct_params(params_hash)
      assert_response 400
      match_json(request_error_pattern(:cannot_create_tracker))
    end
  end

  def test_tracker_create_with_some_invalid_related_tickets
    enable_adv_ticketing([:link_tickets]) do
      agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      tickets = create_related_tickets(2)
      ticket = Helpdesk::Ticket.last
      ticket.update_attributes(association_type: nil)
      params_hash = ticket_params_hash.merge(email: agent.email, related_ticket_ids: tickets.map(&:display_id))
      post :create, construct_params(params_hash)
      assert_response 201
      latest_ticket = Helpdesk::Ticket.last
      match_json(ticket_pattern(latest_ticket).merge!(ticket_association_pattern(latest_ticket)).merge!(failed_related_ticket_ids: [tickets.first.display_id]))
    end
  end

  def test_link_ticket_to_tracker
    enable_adv_ticketing([:link_tickets]) do
      tracker_id = create_tracker_ticket.display_id
      ticket_id = create_ticket.display_id
      put :update, construct_params({ id: ticket_id, tracker_id: tracker_id }, false)
      assert_response 200
      ticket = Helpdesk::Ticket.find_by_display_id(ticket_id)
      tracker_ticket = Helpdesk::Ticket.find_by_display_id(tracker_id)
      assert ticket.related_ticket?
      assert_equal 1, tracker_ticket.subsidiary_tkts_count
    end
  end

  def test_link_to_invalid_tracker
    enable_adv_ticketing([:link_tickets]) do
      tracker_id = create_ticket.display_id
      ticket_id = create_ticket.display_id
      put :update, construct_params({ id: ticket_id, tracker_id: tracker_id }, false)
      pattern = ['tracker_id', :invalid_tracker]
      assert_link_failure(ticket_id, pattern)
    end
  end

  def test_link_to_spammed_tracker
    enable_adv_ticketing([:link_tickets]) do
      tracker = create_tracker_ticket
      tracker.update_attributes(spam: true)
      ticket_id = create_ticket.display_id
      put :update, construct_params({ id: ticket_id, tracker_id: tracker.display_id }, false)
      pattern = ['tracker_id', :invalid_tracker]
      assert_link_failure(ticket_id, pattern)
    end
  end

  def test_link_to_deleted_tracker
    enable_adv_ticketing([:link_tickets]) do
      tracker = create_tracker_ticket
      tracker.update_attributes(deleted: true)
      ticket_id = create_ticket.display_id
      put :update, construct_params({ id: ticket_id, tracker_id: tracker.display_id }, false)
      pattern = ['tracker_id', :invalid_tracker]
      assert_link_failure(ticket_id, pattern)
    end
  end

  def test_link_ticket_without_related_permission
    enable_adv_ticketing([:link_tickets]) do
      ticket_id = create_ticket.display_id
      tracker_id = create_tracker_ticket.display_id
      user_stub_ticket_permission
      put :update, construct_params({ id: ticket_id, tracker_id: tracker_id }, false)
      assert_response 403
      ticket = Helpdesk::Ticket.find_by_display_id(ticket_id)
      assert !ticket.related_ticket?
    end
  ensure
    user_unstub_ticket_permission
  end

  def test_link_ticket_without_tracker_permission
    enable_adv_ticketing([:link_tickets]) do
      ticket_restricted_agent = add_agent_to_group(nil,
                                                   ticket_permission = 3, role_id = @account.roles.agent.first.id)
      ticket = create_ticket(responder_id: ticket_restricted_agent.id)
      tracker_ticket = create_tracker_ticket
      login_as(ticket_restricted_agent)
      put :update, construct_params({ id: ticket.display_id, tracker_id: tracker_ticket.display_id }, false)
      assert_response 200
      ticket = Helpdesk::Ticket.find_by_display_id(ticket.display_id)
      assert ticket.related_ticket?
    end
  end

  def test_link_a_deleted_ticket
    enable_adv_ticketing([:link_tickets]) do
      ticket = create_ticket
      ticket.update_attributes(deleted: true)
      ticket_id = ticket.display_id
      tracker_id = create_tracker_ticket.display_id
      put :update, construct_params({ id: ticket_id, tracker_id: tracker_id }, false)
      assert_response 405
    end
  end

  def test_link_a_spammed_ticket
    enable_adv_ticketing([:link_tickets]) do
      ticket = create_ticket
      ticket.update_attributes(spam: true)
      tracker_id = create_tracker_ticket.display_id
      put :update, construct_params({ id: ticket.display_id, tracker_id: tracker_id }, false)
      assert_response 405
    end
  end

  def test_link_an_associated_ticket_to_tracker
    enable_adv_ticketing([:link_tickets]) do
      ticket = create_ticket
      ticket.update_attributes(association_type: 4)
      tracker_id = create_tracker_ticket.display_id
      put :update, construct_params({ id: ticket.display_id, tracker_id: tracker_id }, false)
      assert_link_failure(nil, [:id, :unable_to_perform])
    end
  end

  def test_link_non_existant_ticket_to_tracker
    enable_adv_ticketing([:link_tickets]) do
      tracker_id = create_tracker_ticket.display_id
      put :update, construct_params({ id: tracker_id + 100, tracker_id: tracker_id }, false)
      assert_response 404
    end
  end

  def test_link_ticket_to_tracker_with_advanced_scope_turned_off
    enable_adv_ticketing([:link_tickets]) do
      Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(false)
      read_access_agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      agent_group = create_agent_group_with_read_access(@account, read_access_agent)
      ticket = create_ticket
      ticket.group_id = agent_group.group_id
      ticket.save!
      login_as(read_access_agent)
      tracker_id = create_tracker_ticket.display_id
      put :update, construct_params({ id: ticket.display_id, tracker_id: tracker_id }, false)
      log_out
      assert_response 403
      read_access_agent.destroy
      Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
    end
  end

  def test_link_ticket_to_tracker_with_advanced_scope_turned_on
    enable_adv_ticketing([:link_tickets]) do
      Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
      read_access_agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      agent_group = create_agent_group_with_read_access(@account, read_access_agent)
      ticket = create_ticket
      ticket.group_id = agent_group.group_id
      ticket.save!
      login_as(read_access_agent)
      tracker_id = create_tracker_ticket.display_id
      put :update, construct_params({ id: ticket.display_id, tracker_id: tracker_id }, false)
      assert_response 200
      ticket = Helpdesk::Ticket.where(display_id: ticket.display_id).first
      tracker_ticket = Helpdesk::Ticket.where(display_id: tracker_id).first
      assert ticket.related_ticket?
      assert_equal 1, tracker_ticket.subsidiary_tkts_count
      log_out
      read_access_agent.destroy
      Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
    end
  end

  def test_create_tracker_ticket_with_advanced_scope_turned_off
    enable_adv_ticketing([:link_tickets]) do
      Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(false)
      read_access_agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      agent_group = create_agent_group_with_read_access(@account, read_access_agent)
      ticket = create_ticket
      ticket.group_id = agent_group.group_id
      ticket.save!
      login_as(read_access_agent)
      Helpdesk::Ticket.any_instance.stubs(:associates=).returns(true)
      params_hash = ticket_params_hash.merge(email: read_access_agent.email, related_ticket_ids: [ticket.display_id])
      post :create, construct_params(params_hash)
      assert_response 400
      log_out
      read_access_agent.destroy
      Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
    end
  end

  def test_create_tracker_ticket_with_advanced_scope_turned_on
    enable_adv_ticketing([:link_tickets]) do
      Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
      read_access_agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      agent_group = create_agent_group_with_read_access(@account, read_access_agent)
      ticket = create_ticket
      ticket.group_id = agent_group.group_id
      ticket.save!
      login_as(read_access_agent)
      tracker_id = create_tracker_ticket.display_id
      put :update, construct_params({ id: ticket.display_id, tracker_id: tracker_id }, false)
      assert_response 200
      ticket = Helpdesk::Ticket.where(display_id: ticket.display_id).first
      tracker_ticket = Helpdesk::Ticket.where(display_id: tracker_id).first
      assert ticket.related_ticket?
      assert_equal 1, tracker_ticket.subsidiary_tkts_count
      log_out
      read_access_agent.destroy
      Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
    end
  end

  def test_link_without_link_tickets_feature
    disable_adv_ticketing([:link_tickets]) if Account.current.launched?(:link_tickets)
    ticket = create_ticket
    ticket_id = ticket.display_id
    tracker_id = create_tracker_ticket.display_id
    put :update, construct_params({ id: ticket_id, tracker_id: tracker_id }, false)
    assert_response 400
    assert !ticket.related_ticket?
    match_json([bad_request_error_pattern('tracker_id', :require_feature_for_attribute,
                                          code: :inaccessible_field, feature: :link_tickets, attribute: 'tracker_id')])
  end

  def test_unlink_related_ticket_from_tracker
    enable_adv_ticketing([:link_tickets]) do
      create_linked_tickets
      Helpdesk::Ticket.any_instance.stubs(:associates).returns([@tracker_id])
      put :update, construct_params({ id: @ticket_id, tracker_id: nil }, false)
      Helpdesk::Ticket.any_instance.unstub(:associates)
      assert_response 200
      ticket = Helpdesk::Ticket.where(display_id: @ticket_id).first
      assert !ticket.related_ticket?
    end
  end

  def test_unlink_and_check_for_subsidiary_tkts_count
    enable_adv_ticketing([:link_tickets]) do
      create_linked_tickets
      put :update, construct_params({ id: @ticket_id, tracker_id: nil }, false)
      assert_response 200
      ticket = Helpdesk::Ticket.where(display_id: @ticket_id).first
      tracker_ticket = Helpdesk::Ticket.where(display_id: @tracker_id).first
      assert tracker_ticket.tracker_ticket?
      assert_equal 0, tracker_ticket.subsidiary_tkts_count
    end
  end

  def test_unlink_non_related_ticket_from_tracker
    enable_adv_ticketing([:link_tickets]) do
      create_linked_tickets
      non_related_ticket_id = create_ticket.display_id
      Helpdesk::Ticket.any_instance.stubs(:associates).returns([@tracker_id])
      put :update, construct_params({ id: non_related_ticket_id, tracker_id: nil }, false)
      Helpdesk::Ticket.any_instance.unstub(:associates)
      assert_response 400
      match_json([bad_request_error_pattern('id', :not_a_related_ticket)])
    end
  end

  def test_unlink_ticket_without_permission
    enable_adv_ticketing([:link_tickets]) do
      create_linked_tickets
      user_stub_ticket_permission
      put :update, construct_params({ id: @ticket_id, tracker_id: nil }, false)
      assert_unlink_failure(@ticket, 403)
    end
  ensure
    user_unstub_ticket_permission
  end

  def test_unlink_non_existant_ticket_from_tracker
    enable_adv_ticketing([:link_tickets]) do
      create_linked_tickets
      Helpdesk::Ticket.where(display_id: @ticket_id).first.destroy
      put :update, construct_params({ id: @ticket_id, tracker_id: nil }, false)
      assert_response 404
    end
  end

  def test_unlink_without_link_tickets_feature
    enable_adv_ticketing([:link_tickets]) { create_linked_tickets }
    disable_adv_ticketing([:link_tickets]) if Account.current.launched?(:link_tickets)
    put :update, construct_params({ id: @ticket_id, tracker_id: nil }, false)
    assert_unlink_failure(@ticket, 400)
    match_json([bad_request_error_pattern('tracker_id', :require_feature_for_attribute,
                                          code: :inaccessible_field, feature: :link_tickets, attribute: 'tracker_id')])
  end

  def test_unlink_related_ticket_from_non_tracker
    enable_adv_ticketing([:link_tickets]) do
      create_linked_tickets
      non_tracker_id = create_ticket.display_id
      Helpdesk::Ticket.any_instance.stubs(:associates).returns([non_tracker_id])
      put :update, construct_params({ id: @ticket_id, tracker_id: nil }, false)
      assert_unlink_failure(@ticket, 400, ['tracker_id', :invalid_tracker])
    end
  ensure
    Helpdesk::Ticket.any_instance.unstub(:associates)
  end

  def test_unlink_without_both_tracker_and_related_permission
    enable_adv_ticketing([:link_tickets]) do
      ticket_restricted_agent = add_agent_to_group(nil,
                                                   ticket_permission = 3, role_id = @account.roles.agent.first.id)
      ticket = create_ticket
      tracker_ticket = create_tracker_ticket
      link_to_tracker(ticket, tracker_ticket)
      login_as(ticket_restricted_agent)
      put :update, construct_params({ id: ticket.display_id, tracker_id: nil }, false)
      assert_response 403
    end
  end

  def test_unlink_with_related_permission_and_without_tracker_permission
    enable_adv_ticketing([:link_tickets]) do
      ticket_restricted_agent = add_agent_to_group(nil,
                                                   ticket_permission = 3, role_id = @account.roles.agent.first.id)
      ticket = create_ticket(responder_id: ticket_restricted_agent.id)
      tracker_ticket = create_tracker_ticket
      link_to_tracker(ticket, tracker_ticket)
      login_as(ticket_restricted_agent)
      put :update, construct_params({ id: ticket.display_id, tracker_id: nil }, false)
      assert_response 200
      ticket = Helpdesk::Ticket.where(display_id: ticket.display_id).first
      assert !ticket.related_ticket?
    end
  end

  def test_unlink_without_related_ticket_permission
    enable_adv_ticketing([:link_tickets]) do
      ticket_restricted_agent = add_agent_to_group(nil,
                                                   ticket_permission = 3, role_id = @account.roles.agent.first.id)
      ticket = create_ticket
      tracker_ticket = create_tracker_ticket(responder_id: ticket_restricted_agent.id)
      link_to_tracker(ticket, tracker_ticket)
      login_as(ticket_restricted_agent)
      put :update, construct_params({ id: ticket.display_id, tracker_id: nil }, false)
      assert_response 200
      ticket = Helpdesk::Ticket.where(display_id: ticket.display_id).first
      assert !ticket.related_ticket?
    end
  end

  def test_unlink_with_other_params
    enable_adv_ticketing([:link_tickets]) do
      ticket_restricted_agent = add_agent_to_group(nil,
                                                   ticket_permission = 3, role_id = @account.roles.agent.first.id)
      ticket = create_ticket
      tracker_ticket = create_tracker_ticket(responder_id: ticket_restricted_agent.id)
      link_to_tracker(ticket, tracker_ticket)
      login_as(ticket_restricted_agent)
      put :update, construct_params({ id: ticket.display_id, tracker_id: nil, status: 5 }, false)
      assert_response 403
    end
  end

  def test_field_agent_update_appointments_with_field_agents_manage_appointments_setting_enabled
    enable_adv_ticketing([:field_service_management]) do
      begin
        perform_fsm_operations
        Account.stubs(:current).returns(Account.first)
        current_user = User.current
        enable_field_agents_can_manage_appointments_option
        Account.current.reload
        time = Time.zone.now
        field_agent = create_field_agent
        fsm_ticket = create_service_task_ticket(fsm_contact_name: 'User', fsm_service_location: 'Location', fsm_phone_number: '9912345678',
                                                fsm_appointment_start_time: time.utc.iso8601, fsm_appointment_end_time: (time + 1.hour).utc.iso8601, responder_id: field_agent.id)
        params = { custom_fields: { cf_fsm_appointment_start_time: (time - 1.hour).utc.iso8601 } }
        login_as(field_agent)
        put :update, construct_params({ id: fsm_ticket.display_id }, params)
        assert_response 200
      ensure
        log_out
        current_user.make_current
        cleanup_fsm
        Account.unstub(:current)
      end
    end
  end

  def test_field_agent_update_appointments_with_field_agents_manage_appointments_setting_disabled
    enable_adv_ticketing([:field_service_management]) do
      begin
        perform_fsm_operations
        Account.stubs(:current).returns(Account.first)
        current_user = User.current
        disable_field_agents_can_manage_appointments_option
        Account.current.reload
        time = Time.zone.now
        field_agent = create_field_agent
        fsm_ticket = create_service_task_ticket(fsm_contact_name: 'User', fsm_service_location: 'Location', fsm_phone_number: '9912345678',
                                                fsm_appointment_start_time: time.utc.iso8601, fsm_appointment_end_time: (time + 1.hour).utc.iso8601, responder_id: field_agent.id)
        params = { custom_fields: { cf_fsm_appointment_start_time: (time - 1.hour).utc.iso8601 } }
        login_as(field_agent)
        put :update, construct_params({ id: fsm_ticket.display_id }, params)
        match_json(
            { "description" => "Validation failed",
              "errors"=>
                  [{ "field" => "custom_fields.cf_fsm_appointment_start_time",
                     "message" => "You are not authorized to perform this action.",
                     "code" => "access_denied" }] })
        assert_response 403
      ensure
        log_out
        current_user.make_current
        cleanup_fsm
        enable_field_agents_can_manage_appointments_option
        Account.unstub(:current)
      end
    end
  end

  def test_support_agent_update_appointments_with_field_agents_manage_appointments_setting_disabled
    enable_adv_ticketing([:field_service_management]) do
      begin
        perform_fsm_operations
        Account.stubs(:current).returns(Account.first)
        disable_field_agents_can_manage_appointments_option
        Account.current.reload
        time = Time.zone.now
        current_user = User.current
        support_agent = add_test_agent(Account.current, role: Role.find_by_name('Agent').id)
        support_agent.make_current
        field_agent = create_field_agent
        fsm_ticket = create_service_task_ticket(fsm_contact_name: 'User', fsm_service_location: 'Location', fsm_phone_number: '9912345678',
                                                fsm_appointment_start_time: time.utc.iso8601, fsm_appointment_end_time: (time + 1.hour).utc.iso8601, responder_id: field_agent.id)
        params = { custom_fields: { cf_fsm_appointment_start_time: (time - 1.hour).utc.iso8601 } }
        put :update, construct_params({ id: fsm_ticket.display_id }, params)
        assert_response 200
      ensure
        log_out
        support_agent.try(:destroy)
        current_user.make_current
        cleanup_fsm
        enable_field_agents_can_manage_appointments_option
        Account.unstub(:current)
      end
    end
  end

  def test_jwe_token_for_get_request_without_privilege
    current_account_id = Account.current.id
    acc = Account.find(current_account_id).make_current
    Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
    ticket = create_ticket
    create_custom_field_dn('custom_card_no_test', 'secure_text')
    uuid = SecureRandom.hex
    request.stubs(:uuid).returns(uuid)
    get :vault_token, controller_params(id: ticket.display_id)
    assert_response 403
  ensure
    ticket.destroy
    request.unstub(:uuid)
    acc.ticket_fields.find_by_name('custom_card_no_test_1').destroy
    Account.any_instance.unstub(:pci_compliance_field_enabled?)
  end

  def test_jwe_token_for_get_request
    current_account_id = Account.current.id
    acc = Account.find(current_account_id).make_current
    Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
    add_privilege(User.current, :view_secure_field)
    ticket = create_ticket
    create_custom_field_dn('custom_card_no_test', 'secure_text')
    uuid = SecureRandom.hex
    request.stubs(:uuid).returns(uuid)
    get :vault_token, controller_params(id: ticket.display_id)
    token = JSON.parse(response.body)['meta']['vault_token']
    key = ApiTicketsTestHelper::PRIVATE_KEY_STRING
    payload = JSON.parse(JWE.decrypt(token, key))
    assert_equal payload['action'], 1
    assert_equal payload['otype'], 'ticket'
    assert_equal payload['oid'], ticket.id
    assert_equal payload['user_id'], User.current.id
    assert_equal payload['uuid'].to_s, uuid
    assert_equal payload['iss'], 'fd/poduseast'
    assert_equal payload['scope'], ['custom_card_no_test']
    assert_equal payload['exp'], payload['iat'] + PciConstants::EXPIRY_DURATION.to_i
    assert_equal payload['accid'], current_account_id
    assert_equal payload['portal'], 1
    assert_response 200
  ensure
    ticket.destroy
    request.unstub(:uuid)
    acc.ticket_fields.find_by_name('custom_card_no_test_1').destroy
    remove_privilege(User.current, :view_secure_field)
    Account.any_instance.unstub(:pci_compliance_field_enabled?)
  end

  def test_jwe_token_generation_for_put_request
    acc = Account.find(Account.current.id).make_current
    Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
    add_privilege(User.current, :view_secure_field)
    add_privilege(User.current, :edit_secure_field)
    create_custom_field_dn('custom_card_no_test', 'secure_text')
    params = ticket_params_hash
    ticket = create_ticket(params)
    update_params = { custom_fields: { '_custom_card_no_test' => 'c0376b8ce26458010ceceb9de2fde759' } }
    put :update, construct_params({ id: ticket.display_id }, update_params)
    assert_response 400
  ensure
    ticket.destroy
    acc.ticket_fields.find_by_name('custom_card_no_test_1').destroy
    remove_privilege(User.current, :view_secure_field)
    remove_privilege(User.current, :edit_secure_field)
    Account.any_instance.unstub(:pci_compliance_field_enabled?)
  end

  def test_index_with_requester_with_public_api_filter_factory_enabled
    user = add_new_user(@account)
    t = create_ticket(requester_id: user.id)
    params = { requester_id: user.id }
    match_query_response_with_es_enabled(params)
  end

  def test_index_with_order_type_and_order_by_with_public_api_filter_factory_enabled
    params = { order_by: 'created_at', order_type: 'asc' }
    match_order_query_with_es_enabled(params)
  end

  def test_index_with_default_fiter_with_public_api_filter_factory_enabled
    params = { filter: 'new_and_my_open' }
    match_query_response_with_es_enabled(params)
  end

  def test_index_with_include_stats_with_public_api_filter_factory_enabled
    params = { include: 'stats' }
    match_query_response_with_es_enabled(params)
  end

  def test_index_with_include_requester_with_public_api_filter_factory_enabled
    params = { include: 'requester' }
    match_query_response_with_es_enabled(params)
  end

  def test_index_with_per_page_with_public_api_filter_factory_enabled
    user = add_new_user(@account)
    5.times { create_ticket(requester_id: user.id) }
    params = { requester_id: user.id, per_page: 3 }
    match_query_response_with_es_enabled(params)
  end

  # Skip mandatory custom field validation on create ticket
  def test_create_ticket_with_enforce_mandatory_true_not_passing_custom_field
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params({},
                                                    create_ticket_params.merge(query_params: { enforce_mandatory: 'true' }))
    result = JSON.parse(created_ticket.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_ticket',
        code: :missing_field,
        message: 'It should be a/an String'
      }]
    )
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_create_ticket_with_enforce_mandatory_true_custom_field_empty
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(custom_fields: { cf_ticket: '' }, query_params: { enforce_mandatory: 'true' })
    )

    result = JSON.parse(created_ticket.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_ticket',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_create_ticket_with_enforce_mandatory_true_passing_custom_field
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(custom_fields: { cf_ticket: 'test' }, query_params: { enforce_mandatory: 'true' })
    )

    result = JSON.parse(created_ticket.body)
    assert_response 201, result
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_create_ticket_with_enforce_mandatory_false_not_passing_custom_field
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
    )

    result = JSON.parse(created_ticket.body)
    assert_response 201, result
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_create_ticket_with_enforce_mandatory_false_custom_field_empty
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(custom_fields: { cf_ticket: '' }, query_params: { enforce_mandatory: 'false' })
    )

    result = JSON.parse(created_ticket.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_ticket',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_create_ticket_with_enforce_mandatory_false_passing_custom_field
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(custom_fields: { cf_ticket: 'test' }, query_params: { enforce_mandatory: 'false' })
    )

    result = JSON.parse(created_ticket.body)
    assert_response 201, result
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_create_ticket_with_enforce_mandatory_as_garbage_value
    create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(custom_fields: { cf_ticket: 'test' }, query_params: { enforce_mandatory: 'test' })
    )

    result = JSON.parse(created_ticket.body)
    assert_response 400, result
    match_json(
      [{
        field: 'enforce_mandatory',
        code: :invalid_value,
        message: "It should be either 'true' or 'false'"
      }]
    )
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  # Skip mandatory custom field validation on update ticket
  def test_update_ticket_without_required_custom_fields_with_enforce_mandatory_as_false
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
    )
    created_ticket_id = JSON.parse(created_ticket.body)['id']
    updated_ticket = put :update, construct_params(
      { id: created_ticket_id },
      description: 'testing',
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(updated_ticket.body)
    assert_response 200, result
    assert_equal result['description'], 'testing'
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_update_ticket_without_required_custom_fields_with_enforce_mandatory_as_true
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
    )
    created_ticket_id = JSON.parse(created_ticket.body)['id']
    updated_ticket = put :update, construct_params(
      { id: created_ticket_id },
      description: 'testing',
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(updated_ticket.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_ticket',
        code: :missing_field,
        message: 'It should be a/an String'
      }]
    )
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_update_ticket_without_required_custom_fields_default_enforce_mandatory_true
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
    )
    created_ticket_id = JSON.parse(created_ticket.body)['id']
    updated_ticket = put :update, construct_params(
      { id: created_ticket_id },
      description: 'testing'
    )

    result = JSON.parse(updated_ticket.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_ticket',
        code: :missing_field,
        message: 'It should be a/an String'
      }]
    )
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_update_ticket_with_enforce_mandatory_true_existing_custom_field_empty_new_empty
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
    )
    created_ticket_id = JSON.parse(created_ticket.body)['id']
    updated_ticket = put :update, construct_params(
      { id: created_ticket_id },
      description: 'testing',
      custom_fields: { cf_ticket: '' },
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(updated_ticket.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_ticket',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_update_ticket_with_enforce_mandatory_true_existing_custom_field_empty_new_not_empty
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
    )
    created_ticket_id = JSON.parse(created_ticket.body)['id']
    updated_ticket = put :update, construct_params(
      { id: created_ticket_id },
      description: 'testing',
      custom_fields: { cf_ticket: 'testing' },
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(updated_ticket.body)
    assert_response 200, result
    assert_equal result['description'], 'testing'
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_update_ticket_with_enforce_mandatory_true_existing_custom_field_not_empty_new_empty
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(custom_fields: { cf_ticket: 'existing' })
    )
    created_ticket_id = JSON.parse(created_ticket.body)['id']
    updated_ticket = put :update, construct_params(
      { id: created_ticket_id },
      description: 'testing',
      custom_fields: { cf_ticket: '' },
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(updated_ticket.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_ticket',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_update_ticket_with_enforce_mandatory_true_existing_custom_field_not_empty_new_not_empty
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(custom_fields: { cf_ticket: 'existing' })
    )
    created_ticket_id = JSON.parse(created_ticket.body)['id']
    updated_ticket = put :update, construct_params(
      { id: created_ticket_id },
      description: 'testing',
      custom_fields: { cf_ticket: 'testing' },
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(updated_ticket.body)
    assert_response 200, result
    assert_equal result['description'], 'testing'
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_update_ticket_with_enforce_mandatory_false_existing_custom_field_empty_new_empty
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
    )
    created_ticket_id = JSON.parse(created_ticket.body)['id']
    updated_ticket = put :update, construct_params(
      { id: created_ticket_id },
      description: 'testing',
      custom_fields: { cf_ticket: '' },
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(updated_ticket.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_ticket',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_update_ticket_with_enforce_mandatory_false_existing_custom_field_empty_new_not_empty
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
    )
    created_ticket_id = JSON.parse(created_ticket.body)['id']
    updated_ticket = put :update, construct_params(
      { id: created_ticket_id },
      description: 'testing',
      custom_fields: { cf_ticket: 'testing' },
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(updated_ticket.body)
    assert_response 200, result
    assert_equal result['description'], 'testing'
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_update_ticket_with_enforce_mandatory_false_existing_custom_field_not_empty_new_empty
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(custom_fields: { cf_ticket: 'existing' })
    )
    created_ticket_id = JSON.parse(created_ticket.body)['id']
    updated_ticket = put :update, construct_params(
      { id: created_ticket_id },
      description: 'testing',
      custom_fields: { cf_ticket: '' },
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(updated_ticket.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_ticket',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_create_ticket_with_enforce_mandatory_false_not_passing_mandatory_dropdown_value
    cf = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
    cf.required = true
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(query_params: { enforce_mandatory: 'false' })
    )

    result = JSON.parse(created_ticket.body)
    assert_response 201, result
  ensure
    cf.required = false
  end

  def test_update_ticket_with_enforce_mandatory_false_existing_custom_field_not_empty_new_not_empty
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(custom_fields: { cf_ticket: 'existing' })
    )
    created_ticket_id = JSON.parse(created_ticket.body)['id']
    updated_ticket = put :update, construct_params(
      { id: created_ticket_id },
      description: 'testing',
      custom_fields: { cf_ticket: 'testing' },
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(updated_ticket.body)
    assert_response 200, result
    assert_equal result['description'], 'testing'
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_create_ticket_with_enforce_mandatory_false_with_wrong_datatype
    cf = create_custom_field('cf_ticket', 'text', '05', true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params.merge(
        custom_fields: { cf_ticket: 123 },
        query_params: { enforce_mandatory: 'false' }
      )
    )

    result = JSON.parse(created_ticket.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_ticket',
        code: :datatype_mismatch,
        message: 'Value set is of type Integer.It should be a/an String'
      }]
    )
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end

  def test_create_ticket_with_enforce_mandatory_false_with_required_for_closure_custom_field
    cf = create_custom_field('cf_ticket', 'text', '05', false, true)
    Account.reset_current_account
    @account = Account.first
    created_ticket = post :create, construct_params(
      {},
      create_ticket_params
    )
    created_ticket_id = JSON.parse(created_ticket.body)['id']

    closed_ticket = put :update, construct_params(
      { id: created_ticket_id },
      status: 5,
      query_params: { enforce_mandatory: 'false' }
    )
    result = JSON.parse(closed_ticket.body)

    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_ticket',
        code: :missing_field,
        message: 'It should be a/an String'
      }]
    )
  ensure
    @account.ticket_fields.find_by_name("cf_ticket_#{@account.id}").destroy
  end


  def test_create_service_task_enforce_mandatory_false_without_contact_name
    enable_adv_ticketing([:field_service_management]) do
      begin
        perform_fsm_operations

        created_ticket = post :create, construct_params(
          {},
          create_ticket_params
        )
        created_ticket_id = JSON.parse(created_ticket.body)['id']

        Account.current.instance_variable_set('@ticket_fields_from_cache', nil)
        Account.reset_current_account

        created_service_task = post :create, construct_params(
          {},
          service_task_params.merge(
            parent_id: created_ticket_id,
            custom_fields: {
              cf_fsm_phone_number: Faker::Lorem.characters(10),
              cf_fsm_service_location: Faker::Lorem.characters(10)
            },
            query_params: { enforce_mandatory: 'false' }
          )
        )
        result = JSON.parse(created_service_task.body)
        assert_response 400, result
        match_json(
          [{
            field: 'cf_fsm_contact_name',
            code: :invalid_value,
            message: "can't be blank"
          }]
        )
      ensure
        cleanup_fsm
      end
    end
  end

  def test_create_service_task_enforce_mandatory_false_without_phone_number
    enable_adv_ticketing([:field_service_management]) do
      begin
        perform_fsm_operations

        created_ticket = post :create, construct_params(
          {},
          create_ticket_params
        )
        created_ticket_id = JSON.parse(created_ticket.body)['id']

        Account.current.instance_variable_set('@ticket_fields_from_cache', nil)
        Account.reset_current_account
        created_service_task = post :create, construct_params(
          {},
          service_task_params.merge(
            parent_id: created_ticket_id,
            custom_fields: {
              cf_fsm_contact_name: Faker::Lorem.characters(10),
              cf_fsm_service_location: Faker::Lorem.characters(10)
            },
            query_params: { enforce_mandatory: 'false' }
          )
        )

        result = JSON.parse(created_service_task.body)
        assert_response 400, result
        match_json(
          [{
            field: 'cf_fsm_phone_number',
            code: :invalid_value,
            message: "can't be blank"
          }]
        )
      ensure
        cleanup_fsm
      end
    end
  end

  def test_create_service_task_enforce_mandatory_false_without_service_location
    enable_adv_ticketing([:field_service_management]) do
      begin
        perform_fsm_operations

        created_ticket = post :create, construct_params(
          {},
          create_ticket_params
        )
        created_ticket_id = JSON.parse(created_ticket.body)['id']

        Account.current.instance_variable_set('@ticket_fields_from_cache', nil)
        Account.reset_current_account
        created_service_task = post :create, construct_params(
          {},
          service_task_params.merge(
            parent_id: created_ticket_id,
            custom_fields: {
              cf_fsm_contact_name: Faker::Lorem.characters(10),
              cf_fsm_phone_number: Faker::Lorem.characters(10)
            },
            query_params: { enforce_mandatory: 'false' }
          )
        )

        result = JSON.parse(created_service_task.body)
        assert_response 400, result
        match_json(
          [{
            field: 'cf_fsm_service_location',
            code: :invalid_value,
            message: "can't be blank"
          }]
        )
      ensure
        cleanup_fsm
      end
    end
  end

  def test_public_api_index_filter_factory_with_read_scope
    order_params = { order_by: 'created_at', order_type: 'asc' }
    enable_public_api_filter_factory([:public_api_filter_factory, :new_es_api, :count_service_es_reads]) do
      User.any_instance.stubs(:access_all_agent_groups).returns(true)
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group.id).first
      agent_group.write_access = false
      agent_group.save!
      agent.make_current
      ticket1 = create_ticket({}, group)
      login_as(agent)
      response_stub = public_api_filter_factory_order_response_stub(order_params[:order_by], order_params[:order_type])
      SearchService::Client.any_instance.stubs(:query).returns(SearchService::Response.new(response_stub))
      SearchService::Response.any_instance.stubs(:records).returns(JSON.parse(response_stub))
      get :index, controller_params(order_params)
      assert_response 200
      match_json(public_api_ticket_index_pattern(false, false, false, order_params[:order_by], order_params[:order_type]))
      agent_group.write_access = true
      agent_group.save!
      User.any_instance.unstub(:access_all_agent_groups)
      ticket1.destroy if ticket1.present?
      agent.destroy if agent.present?
    end
  end

  def test_public_api_index_with_read_scope
    User.any_instance.stubs(:access_all_agent_groups).returns(true)
    agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
    group = create_group_with_agents(@account, agent_list: [agent.id])
    agent_group = agent.agent_groups.where(group_id: group.id).first
    agent_group.write_access = false
    agent_group.save!
    agent.make_current
    ticket1 = create_ticket({}, group)
    login_as(agent)
    get :index, controller_params({})
    assert_response 200
  ensure
    User.any_instance.unstub(:access_all_agent_groups)
    ticket1.destroy if ticket1.present?
    agent.destroy if agent.present?
  end

  def create_ticket_params
    {
      subject: Faker::Lorem.characters(10),
      description: Faker::Lorem.characters(10),
      status: 2,
      priority: 1,
      email: Faker::Internet.email
    }
  end

  def service_task_params
    {
      subject: Faker::Lorem.characters(10),
      description: Faker::Lorem.characters(10),
      status: 2,
      type: 'Service Task',
      priority: 1
    }
  end
end
