require_relative '../../test_helper'
['ticket_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class Ember::CompaniesControllerTest < ActionController::TestCase
  include CompaniesTestHelper
  include SlaPoliciesTestHelper
  include TicketHelper
  include ContactFieldsHelper
  include UsersTestHelper
  include ArchiveTicketTestHelper
  include Redis::RedisKeys
  include Redis::OthersRedis
  include CustomFieldsTestHelper
  include SolutionsTestHelper

  BULK_CREATE_COMPANY_COUNT = 2

  def setup
    super
    initial_setup
  end

  @@initial_setup_run = false

  def initial_setup
    @private_api = true
    return if @@initial_setup_run

    @@initial_setup_run = true
  end

  def wrap_cname(params)
    query_params = params[:query_params]
    cparams = params.clone
    cparams.delete(:query_params)
    return query_params.merge(company: cparams) if query_params

    { company: cparams }
  end

  def teardown
    super
  end

  def create_company(options = {})
    company = @account.companies.find_by_name(options[:name])
    return company if company
    name = options[:name] || Faker::Name.name
    company = FactoryGirl.build(:company, name: name)
    company.account_id = @account.id
    company.avatar = options[:avatar] if options[:avatar]
    company.domains = options[:domains].join(',') if options[:domains].present?
    company.health_score = options[:health_score] if options[:health_score]
    company.account_tier = options[:account_tier] if options[:account_tier]
    company.industry = options[:industry] if options[:industry]
    company.renewal_date = options[:renewal_date] if options[:renewal_date]
    company.save!
    company
  end

  def company_params_hash
    params_hash = {
      name: Faker::Lorem.characters(15)
    }
  end

  def create_archive_tickets(ticket_ids)
    ticket_ids.each do |ticket_id|
      @account.make_current
      Sidekiq::Testing.inline! do
        Archive::TicketWorker.perform_async(account_id: @account.id, ticket_id: ticket_id)
      end
    end
  end

  # Create tests
  def test_create_with_incorrect_avatar_type
    params_hash = company_params_hash.merge(avatar_id: 'ABC')
    post :create, construct_params({ version: 'private' }, params_hash)
    match_json([bad_request_error_pattern(:avatar_id, :datatype_mismatch,
                                          expected_data_type: 'Positive Integer',
                                          prepend_msg: :input_received,
                                          given_data_type: String)])
    assert_response 400
  end

  def test_create_with_invalid_avatar_id
    attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    invalid_id = attachment_id + 10
    params_hash = company_params_hash.merge(avatar_id: invalid_id)
    post :create, construct_params({ version: 'private' }, params_hash)
    match_json([bad_request_error_pattern(:avatar_id, :invalid_list, list: invalid_id.to_s)])
    assert_response 400
  end

  def test_create_with_invalid_avatar_size
    attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    params_hash = company_params_hash.merge(avatar_id: attachment_id)
    Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(20_000_000)
    post :create, construct_params({ version: 'private' }, params_hash)
    Helpdesk::Attachment.any_instance.unstub(:content_file_size)
    match_json([bad_request_error_pattern(:avatar_id, :invalid_size, max_size: '5 MB', current_size: '19.1 MB')])
    assert_response 400
  end

  def test_create_with_invalid_avatar_extension
    attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
    params_hash = company_params_hash.merge(avatar_id: attachment_id)
    post :create, construct_params({ version: 'private' }, params_hash)
    match_json([bad_request_error_pattern(:avatar_id, :upload_jpg_or_png_file, current_extension: '.txt')])
    assert_response 400
  end

  def test_create_with_errors
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
    avatar_id = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
    params_hash = company_params_hash.merge(avatar_id: avatar_id)
    Company.any_instance.stubs(:save).returns(false)
    post :create, construct_params({ version: 'private' }, params_hash)
    Company.any_instance.unstub(:save)
    assert_response 500
  end

  def test_create_with_avatar_id
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
    avatar_id = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
    params_hash = company_params_hash.merge(avatar_id: avatar_id)
    post :create, construct_params({ version: 'private' }, params_hash)
    assert_response 201
    match_json(company_show_pattern(Company.last))
    assert Company.last.avatar.id == avatar_id
  end

  def test_create_with_existing_company_domain
    comp_domain = Faker::Lorem.word
    company = create_company(domains: [comp_domain])
    params_hash = company_params_hash.merge(domains: [comp_domain])
    post :create, construct_params({ version: 'private' }, params_hash)
    response = parse_response @response.body
    error_message = response['errors'][0]['message']
    assert_equal error_message, comp_domain + ' is already taken by the company with company id:' + company.id.to_s
    assert_response 409
  end

  def test_create_company_with_invalid_tam_default_fields
    params_hash = company_params_hash.merge(health_score: Faker::Lorem.characters(5),
                                             account_tier: Faker::Lorem.characters(5))
    post :create, construct_params({ version: 'private' }, params_hash)
    match_json([bad_request_error_pattern('health_score', :not_included,
                                          list: 'At risk,Doing okay,Happy'),
                bad_request_error_pattern('account_tier', :not_included,
                                          list: 'Basic,Premium,Enterprise')])
    assert_response 400
  end

  def test_create_company_with_valid_data_for_tam_default_fields
    params_hash = company_params_hash.merge(health_score: 'Happy',
                                            account_tier: 'Premium',
                                            industry: 'Media',
                                            renewal_date: '2017-10-26')
    post :create, construct_params({ version: 'private' }, params_hash)
    assert_response 201
    match_json(company_show_pattern(Company.last))
  end

  def test_show_a_company
    sample_company = create_company
    get :show, construct_params(version: 'private', id: sample_company.id)
    default_policy = Account.current.sla_policies.default
    match_json(company_show_pattern({ sla_policies: default_policy }, sample_company.reload))
    assert_response 200
    end

  def test_show_a_company_with_avatar
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpeg')
    sample_company = create_company
    sample_company.build_avatar(content_content_type: file.content_type, content_file_name: file.original_filename)
    get :show, construct_params(version: 'private', id: sample_company.id)
    default_policy = Account.current.sla_policies.default
    match_json(company_show_pattern({ sla_policies: default_policy }, sample_company.reload))
    assert_response 200
  end

  def test_show_with_default_sla_policy
    company =  create_company
    get :show, controller_params(version: 'private', id: company.id)
    assert_response 200
    default_policy = Account.current.sla_policies.default
    match_json(company_show_pattern({ sla_policies: default_policy }, company))
  end

  def test_show_with_custom_sla_policies
    sla_policy = quick_create_sla_policy
    company_id = sla_policy.conditions[:company_id].first
    get :show, controller_params(version: 'private', id: company_id)
    assert_response 200
    company = Account.current.companies.find(company_id)
    match_json(company_show_pattern({ sla_policies: [sla_policy.reload] }, company))
  end

  def test_show_a_non_existing_company
    get :show, construct_params(version: 'private', id: 0)
    assert_response :missing
  end

  def test_show_a_company_with_custom_field_date
    company_field = create_company_field(company_params(type: 'date', field_type: 'custom_date', label: 'Company date', name: 'cf_company_date', field_options: { 'widget_position' => 12 }))
    time_now = Time.zone.now
    company = create_company
    company.update_attributes(custom_field: {cf_company_date: time_now})
    @account.reload
    get :show, controller_params(version: 'private', id: company.id)
    assert_response 200
    res = JSON.parse(response.body)
    ticket_date_format = time_now.strftime('%F')
    company_field.destroy
    assert_equal ticket_date_format, res['custom_fields']['company_date']
  end

  def test_index
    BULK_CREATE_COMPANY_COUNT.times do
      create_company
    end
    get :index, controller_params(version: 'private')
    assert_response 200
    pattern = index_company_pattern
    match_json(pattern.ordered!)
  end

  def test_index_with_companies_having_avatar
    BULK_CREATE_COMPANY_COUNT.times do
      company = create_company
      add_avatar_to_company(company)
    end
    get :index, controller_params(version: 'private')
    assert_response 200
    pattern = index_company_pattern
    match_json(pattern.ordered!)
  end

  def test_index_with_invalid_include_associations
    BULK_CREATE_COMPANY_COUNT.times do
      create_company
    end
    invalid_include_list = Faker::Lorem.words(3).uniq
    get :index, controller_params(version: 'private', include: invalid_include_list.join(','))
    assert_response 400
    match_json([bad_request_error_pattern('include', :not_included, list: 'contacts_count')])
  end

  def test_index_with_contacts_count
    BULK_CREATE_COMPANY_COUNT.times do
      company = create_company
      BULK_CREATE_COMPANY_COUNT.times do
        add_new_user(@account, customer_id: company.id)
      end
    end
    include_array = ['contacts_count']
    get :index, controller_params(version: 'private', include: include_array.join(','))
    assert_response 200
    pattern = index_company_pattern({}, include_array)
    match_json(pattern.ordered!)
  end

  def test_index_with_filter
    letter = 'A'
    BULK_CREATE_COMPANY_COUNT.times do
      company =  create_company(name: "#{letter}#{Faker::Lorem.characters(10)}", description: Faker::Lorem.paragraph)
    end
    get :index, controller_params(version: 'private', letter: letter)
    assert_response 200
    response = parse_response @response.body
    assert_equal Account.current.companies.where('name like ?', "#{letter}%").count, response.size
  end

  def test_index_with_ids
    companies = []
    BULK_CREATE_COMPANY_COUNT.times do
      companies << create_company
    end
    get :index, controller_params(version: 'private', ids: companies.map(&:id).join(','))
    assert_response 200
    pattern = []
    companies.each do |company|
      pattern << company_pattern_with_associations({}, company, [])
    end
    match_json(pattern)
  end

  def test_index_with_invalid_ids
    company = create_company
    get :index, controller_params(version: 'private', ids: company.id + 20)
    assert_response 200
    assert_equal parse_response(response.body).size, 0
  end

  def test_index_with_limit_exceeded
    company_ids = Array.new(260) { rand(1...1000) }
    get :index, controller_params(version: 'private', ids: company_ids.join(','))
    assert_response 400
    match_json([bad_request_error_pattern('ids', :too_long, element_type: :values, max_count: Solution::Constants::COMPANIES_LIMIT.to_s, current_count: company_ids.size)])
  end

  def test_index_with_valid_and_invalid_ids
    companies = []
    BULK_CREATE_COMPANY_COUNT.times do
      companies << create_company
    end
    valid_company = companies.first
    company_ids = [companies.first.id, companies.last.id + 20]
    get :index, controller_params(version: 'private', ids: company_ids.join(','))
    assert_response 200
    response = parse_response @response.body
    assert_equal response.size, 1
  end

  def test_index_with_string_ids_params
    get :index, controller_params(version: 'private', ids: 'abc')
    assert_response 400
    match_json([bad_request_error_pattern('ids', :array_datatype_mismatch, expected_data_type: 'Positive Integer')])
  end

  def test_activities_with_invalid_type
    company = create_company
    contact = add_new_user(@account, customer_id: company.id)
    ticket_ids = create_n_tickets(2, requester_id: contact.id)
    get :activities, controller_params(version: 'private', id: company.id, type: Faker::Lorem.word)
    # It will return ticket activities by default.
    assert_response 200
    items = @account.tickets.permissible(@agent).all_company_tickets(company.id).visible.newest(10)
    match_json(company_activity_response(items))
  end

  def test_activities_without_view_contacts_privilege
    company = create_company
    contact = add_new_user(@account, customer_id: company.id)
    ticket_ids = create_n_tickets(2, requester_id: contact.id)
    User.any_instance.stubs(:privilege?).with(:view_contacts).returns(false)
    get :activities, controller_params(version: 'private', id: company.id, type: 'tickets')
    User.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_activities_default
    company =  create_company
    contact = add_new_user(@account, customer_id: company.id)
    ticket_ids = create_n_tickets(2, requester_id: contact.id)
    get :activities, controller_params(version: 'private', id: company.id)
    assert_response 200
    items = @account.tickets.permissible(@agent).all_company_tickets(company.id).visible.newest(10)
    match_json(company_activity_response(items))
  end

  def test_activities_with_type
    company =  create_company
    contact = add_new_user(@account, customer_id: company.id)
    ticket_ids = create_n_tickets(3, requester_id: contact.id)
    get :activities, controller_params(version: 'private', id: company.id, type: 'tickets')
    assert_response 200
    items = @account.tickets.permissible(@agent).all_company_tickets(company.id).visible.newest(3)
    match_json(company_activity_response(items))
  end

  def test_activities_with_archived_tickets
    enable_archive_tickets do
      company =  create_company
      contact = add_new_user(@account, customer_id: company.id)
      ticket_ids = create_n_tickets(3, requester_id: contact.id)
      create_archive_tickets(ticket_ids)
      stub_archive_assoc(account_id: @account.id) do
        get :activities, controller_params(version: 'private', id: company.id, type: 'archived_tickets')
        assert_response 200
        archive_tickets = @account.archive_tickets.permissible(@agent).all_company_tickets(company.id).newest(3)
        match_json(company_activity_response(archive_tickets))
      end
    end
  end

  def test_update_with_existing_company_domain
    comp_domain = Faker::Lorem.words(3).join('')
    company = create_company(domains: [comp_domain])
    other_company = create_company
    post :update, construct_params({ version: 'private', id: other_company.id }, domains: [comp_domain])
    response = parse_response @response.body
    error_message = response['errors'][0]['message']
    assert_equal error_message, comp_domain + ' is already taken by the company with company id:' + company.id.to_s
    assert_response 409
  end

  def test_update_remove_avatar
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
    avatar = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id)
    company = create_company(avatar: avatar)
    put :update, construct_params({ version: 'private', id: company.id }, avatar_id: nil)
    assert_response 200
    company.reload
    match_json(company_show_pattern(company))
    assert company.avatar.nil?
  end

  def test_update_change_avatar
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
    avatar = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id)
    company = create_company(avatar: avatar)
    new_avatar = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id)
    put :update, construct_params({ version: 'private', id: company.id }, avatar_id: new_avatar.id)
    assert_response 200
    company.reload
    match_json(company_show_pattern(company))
    assert company.avatar.id == new_avatar.id
  end

  def test_update_add_avatar
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
    avatar = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id)
    company = create_company
    put :update, construct_params({ version: 'private', id: company.id }, avatar_id: avatar.id)
    assert_response 200
    company.reload
    match_json(company_show_pattern(company))
    assert company.avatar.id == avatar.id
  end

  def test_update_company_with_invalid_tam_default_fields
    company = create_company
    params_hash = { health_score: Faker::Lorem.characters(5), account_tier: Faker::Lorem.characters(5) }
    put :update, construct_params({ version: 'private', id: company.id }, params_hash)
    match_json([bad_request_error_pattern('health_score', :not_included,
                                          list: 'At risk,Doing okay,Happy'),
                bad_request_error_pattern('account_tier', :not_included, list: 'Basic,Premium,Enterprise')])
    assert_response 400
  end

  def test_update_company_with_valid_data_for_tam_default_fields
    company = create_company
    put :update, construct_params({ version: 'private', id: company.id },
                                    { health_score: 'Happy', account_tier: 'Premium',
                                    industry: 'Media', renewal_date: '2017-10-26' })
    
    assert_response 200
    match_json(company_show_pattern(company.reload))
  end

  def test_company_create_central_payload
    CentralPublishWorker::CompanyWorker.jobs.clear
    company = create_company
    assert_response 200
    job = CentralPublishWorker::CompanyWorker.jobs.last
    assert_equal 'company_create', job['args'][0]
    CentralPublishWorker::CompanyWorker.jobs.clear
  end

  def test_company_update_central_payload
    CentralPublishWorker::CompanyWorker.jobs.clear
    company = create_company
    put :update, construct_params({ version: 'private', id: company.id }, { account_tier: 'Premium', industry: 'Media' })
    assert_response 200
    job = CentralPublishWorker::CompanyWorker.jobs.last
    assert_equal 'company_update', job['args'][0]
    assert_equal([nil, 'Premium'], job['args'][1]['model_changes']['string_cc02'])
    CentralPublishWorker::CompanyWorker.jobs.clear
  end

  def test_company_delete_central_payload
    CentralPublishWorker::CompanyWorker.jobs.clear
    company = create_company
    delete :destroy, construct_params(id: company.id)
    assert_response 204
    job = CentralPublishWorker::CompanyWorker.jobs.last
    assert_equal 'company_destroy', job['args'][0]
    CentralPublishWorker::CompanyWorker.jobs.clear
  end

  def test_bulk_delete_with_no_params
    put :bulk_delete, construct_params({ version: 'private' }, {})
    assert_response 400
    match_json([bad_request_error_pattern('ids', :missing_field)])
  end

  def test_bulk_delete_with_invalid_ids
    company_ids = []
    BULK_CREATE_COMPANY_COUNT.times do
      company_ids << create_company.id
    end
    invalid_ids = [company_ids.last + 20, company_ids.last + 30]
    ids_to_delete = [*company_ids, *invalid_ids]
    put :bulk_delete, construct_params({ version: 'private' }, ids: ids_to_delete)
    failures = {}
    invalid_ids.each { |id| failures[id] = { id: :"is invalid" } }
    match_json(partial_success_response_pattern(company_ids, failures))
    assert_response 202
  end

  def test_bulk_delete_with_errors_in_deletion
    companies = []
    BULK_CREATE_COMPANY_COUNT.times do
      companies << create_company
    end
    ids_to_delete = companies.map(&:id)
    Company.any_instance.stubs(:destroy).returns(false)
    put :bulk_delete, construct_params({ version: 'private' }, ids: ids_to_delete)
    failures = {}
    ids_to_delete.each { |id| failures[id] = { id: :unable_to_perform } }
    match_json(partial_success_response_pattern([], failures))
    assert_response 202
  end

  def test_bulk_delete_with_valid_ids
    company_ids = []
    BULK_CREATE_COMPANY_COUNT.times do
      company_ids << create_company.id
    end
    put :bulk_delete, construct_params({ version: 'private' }, ids: company_ids)
    assert_response 204
  end

  def test_update_company_with_custom_fields
    choices = [{ value: 'Choice 1', position: 1 }, { value: 'Choice 2', position: 2 }]
    cf_params = company_params(type: 'dropdown', field_type: 'custom_dropdown', label: 'Company Dropdown', name: 'cf_company_dropdown', custom_field_choices_attributes: choices)
    company_field = create_company_field(cf_params)
    company = create_company
    put :update, construct_params({ version: 'private', id: company.id }, custom_fields: { company_dropdown: choices.last[:value] })
    assert_response 200
  ensure
    company_field.destroy
  end

  def test_create_with_invalid_email_and_custom_field
    field = { type: 'text', field_type: 'custom_text', label: 'note'}
    params = company_params(field)
    create_company_field params
    create_params = company_params_hash.merge(custom_fields: { custom_note: 0 })
    create_params[:note] = 0.00
    post :create, construct_params({ version: 'private' }, create_params)
    match_json([
      bad_request_error_pattern(:note, :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Float', prepend_msg: :input_received), 
      bad_request_error_pattern(custom_field_error_label('custom_note'), :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received)
    ])
    assert_response 400
  end

  # Skip mandatory custom field validation on create company
  def test_create_company_with_enforce_mandatory_true_not_passing_custom_field
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      query_params: { enforce_mandatory: 'true' }
    )
    result = JSON.parse(created_company.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_company',
        code: :missing_field,
        message: 'It should be a/an String'
      }]
    )
  ensure
    cf.delete
  end

  def test_create_company_with_enforce_mandatory_true_custom_field_empty
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      custom_fields: { cf_company: '' },
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(created_company.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_company',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    cf.delete
  end

  def test_create_company_with_enforce_mandatory_true_passing_custom_field
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      custom_fields: { cf_company: 'test' },
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(created_company.body)
    assert_response 201, result
  ensure
    cf.delete
  end

  def test_create_company_with_enforce_mandatory_false_not_passing_custom_field
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(created_company.body)
    assert_response 201, result
  ensure
    cf.delete
  end

  def test_create_company_with_enforce_mandatory_false_custom_field_empty
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      custom_fields: { cf_company: '' },
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(created_company.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_company',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    cf.delete
  end

  def test_create_company_with_enforce_mandatory_false_passing_custom_field
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      custom_fields: { cf_company: 'test' },
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(created_company.body)
    assert_response 201, result
  ensure
    cf.delete
  end

  def test_create_company_with_enforce_mandatory_as_garbage_value
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      custom_fields: { cf_company: 'test' },
      query_params: { enforce_mandatory: 'test' }
    )

    result = JSON.parse(created_company.body)
    assert_response 400, result
    match_json(
      [{
        field: 'enforce_mandatory',
        code: :invalid_value,
        message: "It should be either 'true' or 'false'"
      }]
    )
  ensure
    cf.delete
  end

  # Skip mandatory custom field validation on update company
  def test_update_company_without_required_custom_fields_with_enforce_mandatory_as_false
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      query_params: { enforce_mandatory: 'false' }
    )
    created_company_id = JSON.parse(created_company.body)['id']
    updated_company = put :update, construct_params(
      { version: 'private', id: created_company_id },
      description: 'testing',
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(updated_company.body)
    assert_response 200, result
    assert_equal result['description'], 'testing'
  ensure
    cf.delete
  end

  def test_update_company_without_required_custom_fields_with_enforce_mandatory_as_true
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      query_params: { enforce_mandatory: 'false' }
    )
    created_company_id = JSON.parse(created_company.body)['id']
    updated_company = put :update, construct_params(
      { version: 'private', id: created_company_id },
      description: 'testing',
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(updated_company.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_company',
        code: :missing_field,
        message: 'It should be a/an String'
      }]
    )
  ensure
    cf.delete
  end

  def test_update_company_without_required_custom_fields_default_enforce_mandatory_true
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      query_params: { enforce_mandatory: 'false' }
    )
    created_company_id = JSON.parse(created_company.body)['id']
    updated_company = put :update, construct_params(
      { version: 'private', id: created_company_id },
      description: 'testing'
    )

    result = JSON.parse(updated_company.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_company',
        code: :missing_field,
        message: 'It should be a/an String'
      }]
    )
  ensure
    cf.delete
  end

  def test_update_company_with_enforce_mandatory_true_existing_custom_field_empty_new_empty
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      query_params: { enforce_mandatory: 'false' }
    )
    created_company_id = JSON.parse(created_company.body)['id']
    updated_company = put :update, construct_params(
      { version: 'private', id: created_company_id },
      description: 'testing',
      custom_fields: { cf_company: '' },
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(updated_company.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_company',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    cf.delete
  end

  def test_update_company_with_enforce_mandatory_true_existing_custom_field_empty_new_not_empty
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      query_params: { enforce_mandatory: 'false' }
    )
    created_company_id = JSON.parse(created_company.body)['id']
    updated_company = put :update, construct_params(
      { version: 'private', id: created_company_id },
      description: 'testing',
      custom_fields: { cf_company: 'testing' },
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(updated_company.body)
    assert_response 200, result
    assert_equal result['description'], 'testing'
  ensure
    cf.delete
  end

  def test_update_company_with_enforce_mandatory_true_existing_custom_field_not_empty_new_empty
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      custom_fields: { cf_company: 'existing' }
    )
    created_company_id = JSON.parse(created_company.body)['id']
    updated_company = put :update, construct_params(
      { version: 'private', id: created_company_id },
      description: 'testing',
      custom_fields: { cf_company: '' },
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(updated_company.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_company',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    cf.delete
  end

  def test_update_company_with_enforce_mandatory_true_existing_custom_field_not_empty_new_not_empty
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      custom_fields: { cf_company: 'existing' }
    )
    created_company_id = JSON.parse(created_company.body)['id']
    updated_company = put :update, construct_params(
      { version: 'private', id: created_company_id },
      description: 'testing',
      custom_fields: { cf_company: 'testing' },
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(updated_company.body)
    assert_response 200, result
    assert_equal result['description'], 'testing'
  ensure
    cf.delete
  end

  def test_update_company_with_enforce_mandatory_false_existing_custom_field_empty_new_empty
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      query_params: { enforce_mandatory: 'false' }
    )
    created_company_id = JSON.parse(created_company.body)['id']
    updated_company = put :update, construct_params(
      { version: 'private', id: created_company_id },
      description: 'testing',
      custom_fields: { cf_company: '' },
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(updated_company.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_company',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    cf.delete
  end

  def test_update_company_with_enforce_mandatory_false_existing_custom_field_empty_new_not_empty
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      query_params: { enforce_mandatory: 'false' }
    )
    created_company_id = JSON.parse(created_company.body)['id']
    updated_company = put :update, construct_params(
      { version: 'private', id: created_company_id },
      description: 'testing',
      custom_fields: { cf_company: 'testing' },
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(updated_company.body)
    assert_response 200, result
    assert_equal result['description'], 'testing'
  ensure
    cf.delete
  end

  def test_update_company_with_enforce_mandatory_false_existing_custom_field_not_empty_new_empty
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      custom_fields: { cf_company: 'existing' }
    )
    created_company_id = JSON.parse(created_company.body)['id']
    updated_company = put :update, construct_params(
      { version: 'private', id: created_company_id },
      description: 'testing',
      custom_fields: { cf_company: '' },
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(updated_company.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.cf_company',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    cf.delete
  end

  def test_update_company_with_enforce_mandatory_false_existing_custom_field_not_empty_new_not_empty
    cf = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'cf_company', required_for_agent: 'true'))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      custom_fields: { cf_company: 'existing' }
    )
    created_company_id = JSON.parse(created_company.body)['id']
    updated_company = put :update, construct_params(
      { version: 'private', id: created_company_id },
      description: 'testing',
      custom_fields: { cf_company: 'testing' },
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(updated_company.body)
    assert_response 200, result
    assert_equal result['description'], 'testing'
  ensure
    cf.delete
  end

  def test_create_company_with_enforce_mandatory_false_not_passing_mandatory_dropdown_value
    cf = create_company_field(company_params(
                                type: 'dropdown',
                                field_type: 'custom_dropdown',
                                label: 'cf_company',
                                required_for_agent: 'true',
                                custom_field_choices_attributes: [
                                  {
                                    value: 'First Choice',
                                    position: 1,
                                    _destroy: 0,
                                    name: 'First Choice'
                                  },
                                  {
                                    value: 'Second Choice',
                                    position: 2,
                                    _destroy: 0,
                                    name: 'Second Choice'
                                  }
                                ]
    ))
    @account.reload
    created_company = post :create, construct_params(
      { version: 'private' },
      name: Faker::Lorem.characters(15),
      query_params: { enforce_mandatory: 'false' }
    )
    result = JSON.parse(created_company.body)

    assert_response 201, result
  ensure
    cf.delete
  end
end
