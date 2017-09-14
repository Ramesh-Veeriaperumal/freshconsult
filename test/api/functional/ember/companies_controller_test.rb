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
    { company: params }
  end

  def create_company(options = {})
    company = @account.companies.find_by_name(options[:name])
    return company if company
    name = options[:name] || Faker::Name.name
    company = FactoryGirl.build(:company, name: name)
    company.account_id = @account.id
    company.avatar = options[:avatar] if options[:avatar]
    company.domains = options[:domains].join(',') if options[:domains].present?
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
        Archive::BuildCreateTicket.perform_async(account_id: @account.id, ticket_id: ticket_id)
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
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
    avatar_id = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
    params_hash = company_params_hash.merge(avatar_id: avatar_id)
    Company.any_instance.stubs(:save).returns(false)
    post :create, construct_params({ version: 'private' }, params_hash)
    Company.any_instance.unstub(:save)
    assert_response 500
  end

  def test_create_with_avatar_id
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
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
    assert_response 409
  end

  def test_show_a_company
    sample_company = create_company
    get :show, construct_params(version: 'private', id: sample_company.id)
    default_policy = Account.current.sla_policies.default
    match_json(company_show_pattern({ sla_policies: default_policy }, sample_company.reload))
    assert_response 200
    end

  def test_show_a_company_with_avatar
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
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

  def test_index
    rand(2..5).times do
      create_company
    end
    get :index, controller_params(version: 'private')
    assert_response 200
    pattern = index_company_pattern
    match_json(pattern.ordered!)
  end

  def test_index_with_companies_having_avatar
    rand(2..5).times do
      company = create_company
      add_avatar_to_company(company)
    end
    get :index, controller_params(version: 'private')
    assert_response 200
    pattern = index_company_pattern
    match_json(pattern.ordered!)
  end

  def test_index_with_invalid_include_associations
    rand(2..5).times do
      create_company
    end
    invalid_include_list = Faker::Lorem.words(3).uniq
    get :index, controller_params(version: 'private', include: invalid_include_list.join(','))
    assert_response 400
    match_json([bad_request_error_pattern('include', :not_included, list: 'contacts_count')])
  end

  def test_index_with_contacts_count
    rand(2..5).times do
      company = create_company
      rand(2..5).times do
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
    rand(2..5).times do
      company =  create_company(name: "#{letter}#{Faker::Lorem.characters(10)}", description: Faker::Lorem.paragraph)
    end
    get :index, controller_params(version: 'private', letter: letter)
    assert_response 200
    response = parse_response @response.body
    assert_equal Account.current.companies.where('name like ?', "#{letter}%").count, response.size
  end

  def test_activities_with_invalid_type
    company = create_company
    contact = add_new_user(@account, customer_id: company.id)
    ticket_ids = []
    rand(5..10).times do
      ticket_ids << create_ticket(requester_id: contact.id).id
    end
    get :activities, controller_params(version: 'private', id: company.id, type: Faker::Lorem.word)
    # It will return ticket activities by default.
    assert_response 200
    items = @account.tickets.permissible(@agent).all_company_tickets(company.id).visible.newest(10)
    match_json(company_activity_response(items))
  end

  def test_activities_default
    company =  create_company
    contact = add_new_user(@account, customer_id: company.id)
    ticket_ids = []
    rand(5..10).times do
      ticket_ids << create_ticket(requester_id: contact.id).id
    end
    get :activities, controller_params(version: 'private', id: company.id)
    assert_response 200
    items = @account.tickets.permissible(@agent).all_company_tickets(company.id).visible.newest(10)
    match_json(company_activity_response(items))
  end

  def test_activities_with_type
    company =  create_company
    contact = add_new_user(@account, customer_id: company.id)
    ticket_ids = []
    11.times do
      ticket_ids << create_ticket(requester_id: contact.id).id
    end
    get :activities, controller_params(version: 'private', id: company.id, type: 'tickets')
    assert_response 200
    items = @account.tickets.permissible(@agent).all_company_tickets(company.id).visible.newest(10)
    match_json(company_activity_response(items))
  end

  def test_activities_with_archived_tickets
    enable_archive_tickets do
      company =  create_company
      contact = add_new_user(@account, customer_id: company.id)
      ticket_ids = []
      11.times do
        ticket_ids << create_ticket(requester_id: contact.id, status: 5).id
      end
      create_archive_tickets(ticket_ids)
      stub_archive_assoc(account_id: @account.id) do
        get :activities, controller_params(version: 'private', id: company.id, type: 'archived_tickets')
        assert_response 200
        archive_tickets = @account.archive_tickets.permissible(@agent).all_company_tickets(company.id).newest(10)
        match_json(company_activity_response(archive_tickets))
      end
    end
  end

  def test_update_with_existing_company_domain
    comp_domain = Faker::Lorem.word
    company = create_company(domains: [comp_domain])
    other_company = create_company
    post :update, construct_params({ version: 'private', id: other_company.id }, domains: [comp_domain])
    assert_response 409
  end

  def test_update_remove_avatar
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
    avatar = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id)
    company = create_company(avatar: avatar)
    put :update, construct_params({ version: 'private', id: company.id }, avatar_id: nil)
    assert_response 200
    company.reload
    match_json(company_show_pattern(company))
    assert company.avatar.nil?
  end

  def test_update_change_avatar
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
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
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
    avatar = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id)
    company = create_company
    put :update, construct_params({ version: 'private', id: company.id }, avatar_id: avatar.id)
    assert_response 200
    company.reload
    match_json(company_show_pattern(company))
    assert company.avatar.id == avatar.id
  end

  def test_bulk_delete_with_no_params
    put :bulk_delete, construct_params({ version: 'private' }, {})
    assert_response 400
    match_json([bad_request_error_pattern('ids', :missing_field)])
  end

  def test_bulk_delete_with_invalid_ids
    company_ids = []
    rand(2..10).times do
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
    rand(2..10).times do
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
    rand(2..10).times do
      company_ids << create_company.id
    end
    put :bulk_delete, construct_params({ version: 'private' }, ids: company_ids)
    assert_response 204
  end

  def test_export_csv_with_no_params
    rand(2..10).times do
      create_company
    end
    company_form = @account.company_form
    post :export_csv, construct_params({version: 'private'}, {})
    assert_response 400
    match_json([bad_request_error_pattern(:request, :select_a_field)])
  end

  def test_export_csv_with_invalid_params
    rand(2..10).times do
      create_company
    end
    company_form = @account.company_form
    params_hash = { default_fields: [Faker::Lorem.word], custom_fields: [Faker::Lorem.word] }
    post :export_csv, construct_params({version: 'private'}, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(:default_fields, :not_included, list: (company_form.default_company_fields.map(&:name)).join(',')),
                bad_request_error_pattern(:custom_fields, :not_included, list: (company_form.custom_company_fields.map(&:name).collect { |x| x[3..-1] }).join(','))])
  end

  def test_export_csv_sidekiq
    create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'Location', editable_in_signup: 'true'))
    create_company_field(company_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Area of specification', editable_in_signup: 'true'))

    rand(2..10).times do
      create_company(@account)
    end

    default_fields = @account.company_form.default_company_fields
    custom_fields = @account.company_form.custom_company_fields
    Export::CompanyWorker.jobs.clear
    set_others_redis_key(COMPANIES_EXPORT_SIDEKIQ_ENABLED, true)
    params_hash = { default_fields: default_fields.map(&:name), custom_fields: custom_fields.map(&:name).collect { |x| x[3..-1] } }
    post :export_csv, construct_params({version: 'private'}, params_hash)
    assert_response 204
    sidekiq_jobs = Export::CompanyWorker.jobs
    assert_equal 1, sidekiq_jobs.size
    csv_hash = (default_fields | custom_fields).collect{ |x| { x.label => x.name } }.inject(&:merge)
    assert_equal csv_hash, sidekiq_jobs.first["args"][0]["csv_hash"]
    assert_equal User.current.id, sidekiq_jobs.first["args"][0]["user"]
    Export::CompanyWorker.jobs.clear
    remove_others_redis_key(COMPANIES_EXPORT_SIDEKIQ_ENABLED)
  end

  def test_export_csv_resque
    create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'Location', editable_in_signup: 'true'))
    create_company_field(company_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Area of specification', editable_in_signup: 'true'))

    rand(2..10).times do
      create_company(@account)
    end

    default_fields = @account.company_form.default_company_fields
    custom_fields = @account.company_form.custom_company_fields
    Resque.inline = true
    params_hash = { default_fields: default_fields.map(&:name), custom_fields: custom_fields.map(&:name).collect { |x| x[3..-1] } }
    post :export_csv, construct_params({version: 'private'}, params_hash)
    assert_response 204
    Resque.inline = false
  end
end
