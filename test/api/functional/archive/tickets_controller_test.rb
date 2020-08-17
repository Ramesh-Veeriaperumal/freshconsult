require_relative '../../test_helper'
['social_tickets_creation_helper'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class Archive::TicketsControllerTest < ActionController::TestCase
  include ArchiveTicketTestHelper
  include ApiTicketsTestHelper
  include TicketHelper
  include ContactFieldsHelper
  include SocialTicketsCreationHelper
  include Crypto::TokenHashing

  ARCHIVE_DAYS = 120
  TICKET_UPDATED_DATE = 150.days.ago
  ARCHIVE_TICKETS_COUNT = 5
  EXCLUDE_ATTRIBUTES_FOR_SHOW = [:email_config_id, :association_type].freeze

  def setup
    super
    @account.make_current
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    Sidekiq::Worker.clear_all
    Account.any_instance.stubs(:agent_collision_revamp_enabled?).returns(true)
    create_archive_ticket
  end

  def teardown
    cleanup_archive_ticket(@archive_ticket, {conversations: true})
  end

  def wrap_cname(params)
    { ticket: params }
  end

  def test_show
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)
      return if archive_ticket.blank?

      get :show, controller_params(id: archive_ticket.display_id, include: 'stats')
      assert_response 200

      ticket_pattern = ticket_pattern_for_show(archive_ticket)
      match_json(ticket_pattern)
    end
  end

  def test_archive_ticket_show_with_read_scope
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.where(ticket_id: @archive_ticket.id).first
      return if archive_ticket.blank?

      user = User.current
      permission = user.agent.ticket_permission
      group = create_group_with_agents(Account.current, agent_list: [user.id])
      user.agent.update_attributes(ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
      archive_ticket_group_id = archive_ticket.group_id
      archive_ticket.group_id = group.id
      archive_ticket.save
      get :show, controller_params(id: archive_ticket.display_id, include: 'stats')
      assert_response 200
      archive_ticket.group_id = archive_ticket_group_id
      archive_ticket.save
      ticket_pattern = ticket_pattern_for_show(archive_ticket)
      response = JSON.parse(@response.body)
      assert_equal response['id'], archive_ticket.display_id
      user.agent.update_attributes(ticket_permission: permission)
      group.destroy if group.present?
      Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
    end
  end

  def test_show_with_custom_file_field
    custom_field = create_custom_field_dn('test_signature_file', 'file')
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)
      return if archive_ticket.blank?

      @account.features.send(:archive_tickets).create unless @account.archive_tickets_enabled?

      get :show, controller_params(id: archive_ticket.display_id, include: 'stats')
      response = parse_response @response.body
      assert_response 200, response
      file_field = response['custom_fields'].key? 'test_signature_file'
      assert_equal true, file_field
    end
  ensure
    custom_field.destroy
  end

  def test_show_with_empty_conversations
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)
      return if archive_ticket.blank?

      get :show, controller_params(id: archive_ticket.display_id, include: 'stats,conversations')
      assert_response 200

      ticket_pattern = ticket_pattern_for_show(archive_ticket)
      ticket_pattern['conversations'] = []
      match_json(ticket_pattern)
    end
  end

  def test_show_with_requester
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)
      return if archive_ticket.blank?

      get :show, controller_params(id: archive_ticket.display_id, include: 'stats,requester')
      assert_response 200

      ticket_pattern = ticket_pattern_for_show(archive_ticket, [:requester])
      match_json(ticket_pattern)
    end
  end

  def test_show_without_ticket
    get :show, controller_params(id: 'x')
    assert_response 404
  end

  def test_show_without_permission
    stub_archive_assoc_for_show(@archive_association) do
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)
      get :show, controller_params(id: archive_ticket.display_id)
      User.any_instance.unstub(:has_ticket_permission?)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end
  end

  def test_show_with_invalid_params
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)
      return if archive_ticket.blank?

      get :show, controller_params(id: archive_ticket.display_id, include: 'invalid')
      assert_response 400
    end
  end

  def test_archive_twitter_ticket_show_with_restricted_tweet_content
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    CustomRequestStore.store[:private_api_request] = false
    create_archive_ticket(twitter_ticket: true, tweet_type: 'mention')
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id(@archive_ticket.id)
      return if archive_ticket.blank?

      get :show, controller_params(id: archive_ticket.display_id, include: 'stats')
      assert_response 200

      ticket_pattern = ticket_pattern_for_show(archive_ticket)
      match_json(ticket_pattern)
    end
  ensure
    CustomRequestStore.store[:private_api_request] = true
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
  end

  def test_archive_twitter_ticket_show_with_unrestricted_tweet_content
    CustomRequestStore.store[:private_api_request] = false
    create_archive_ticket(twitter_ticket: true, tweet_type: 'mention')
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id(@archive_ticket.id)
      return if archive_ticket.blank?

      get :show, controller_params(id: archive_ticket.display_id, include: 'stats')
      assert_response 200

      ticket_pattern = ticket_pattern_for_show(archive_ticket)
      match_json(ticket_pattern)
    end
  ensure
    CustomRequestStore.store[:private_api_request] = true
  end

  def test_archive_twitter_ticket_show_with_restricted_dm_content
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    CustomRequestStore.store[:private_api_request] = false
    create_archive_ticket(twitter_ticket: true, tweet_type: 'dm')
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id(@archive_ticket.id)
      return if archive_ticket.blank?

      get :show, controller_params(id: archive_ticket.display_id, include: 'stats')
      assert_response 200

      ticket_pattern = ticket_pattern_for_show(archive_ticket)
      match_json(ticket_pattern)
    end
  ensure
    CustomRequestStore.store[:private_api_request] = true
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
  end

  def test_archive_twitter_ticket_show_with_unrestricted_dm_content
    CustomRequestStore.store[:private_api_request] = false
    create_archive_ticket(twitter_ticket: true, tweet_type: 'dm')
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id(@archive_ticket.id)
      return if archive_ticket.blank?

      get :show, controller_params(id: archive_ticket.display_id, include: 'stats')
      assert_response 200

      ticket_pattern = ticket_pattern_for_show(archive_ticket)
      match_json(ticket_pattern)
    end
  ensure
    CustomRequestStore.store[:private_api_request] = true
  end

  def test_without_archive_feature
    Account.any_instance.stubs(:enabled_features_list).returns([])
    get :show, controller_params(id: 1)
    assert_response 403
    Account.any_instance.unstub(:enabled_features_list)
  end

  def test_export_with_no_params
    post :export, construct_params({ version: 'private' }, {})
    assert_response 400
    match_json([bad_request_error_pattern('format', :missing_field),
                bad_request_error_pattern('query', :missing_field),
                bad_request_error_pattern('export_name', :missing_field)])
  end

  def test_export_with_invalid_params
    contact_fields = @account.contact_form.fields
    company_fields = @account.company_form.fields
    User.any_instance.stubs(:privilege?).with(:export_tickets).returns(true)
    User.any_instance.stubs(:privilege?).with(:export_customers).returns(false)      
    params_hash = { format: Faker::Lorem.word, ticket_fields: { id: rand(2..10) },
                  contact_fields: { id: rand(2..10) },
                  company_fields: { id: rand(2..10) },
                  query: [123],
                  export_name: [22] }
    post :export, construct_params({ version: 'private' }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(:format, :not_included, list: %w(csv xls).join(',')),
                bad_request_error_pattern(:query, :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Array', prepend_msg: :input_received),
                bad_request_error_pattern(:export_name, :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Array', prepend_msg: :input_received),
                bad_request_error_pattern(:ticket_fields, :not_included, list: ticket_export_fields.join(',')),
                bad_request_error_pattern(:contact_fields, :not_included, list: %i(name phone mobile fb_profile_id contact_id).join(',')),
                bad_request_error_pattern(:company_fields, :not_included, list: %i(name).join(','))])            
    User.any_instance.unstub(:privilege?)
  end

  def test_export_with_valid_params
    params_hash = { ticket_fields: {"display_id":"Ticket ID","subject":"Subject"},
                    contact_fields: { 'name' => 'Requester Name', 'mobile' => 'Mobile Phone' },
                    company_fields: { 'name' => 'Company Name' },
                    format: 'csv',
                    query: "priority:1",
                    export_name: "Test export" }
    post :export, construct_params({ version: 'private' }, params_hash)
    assert_response 204
  end

  def test_export_inline_with_valid_params
    params_hash = { ticket_fields: export_ticket_fields,
                    contact_fields: { 'name' => 'Requester Name', 'mobile' => 'Mobile Phone' },
                    company_fields: { 'name' => 'Company Name' },
                    format: 'csv',
                    query: "priority:2",
                    export_name: "Test export" }
    archive_tickets = @account.archive_tickets
    initial_count = ticket_data_export(DataExport::EXPORT_TYPE[:archive_ticket]).count
    SchedulerService::Client.any_instance.stubs(:schedule_job).returns(status: 200, body: "")
    search_stub_archive_tickets(archive_tickets) do
      Sidekiq::Testing.inline! do
        post :export, construct_params({ version: 'private' }, params_hash)
      end
    end
    current_data_exports = ticket_data_export(DataExport::EXPORT_TYPE[:archive_ticket])
    assert_equal initial_count, current_data_exports.length - 1
    SchedulerService::Client.unstub(:schedule_job)
  end

  def test_export_with_invalid_query
    params_hash = { ticket_fields: {"display_id":"Ticket ID","subject":"Subject"},
                    contact_fields: { 'name' => 'Requester Name', 'mobile' => 'Mobile Phone' },
                    company_fields: { 'name' => 'Company Name' },
                    format: 'csv',
                    query: "priority:0",
                    export_name: "Test export" }
    post :export, construct_params({ version: 'private' }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(:query, "", {:prepend_msg => "priority:It should be one of these values: '1,2,3,4'"})])

  end

  def test_export_with_query_more_than_limit
    query = 'a' * (ExportHelper::MAX_QUERY_LIMIT + 1)
    params_hash = { ticket_fields: {"display_id":"Ticket ID","subject":"Subject"},
                    contact_fields: { 'name' => 'Requester Name', 'mobile' => 'Mobile Phone' },
                    company_fields: { 'name' => 'Company Name' },
                    format: 'csv',
                    query: query,
                    export_name: "Test export" }
    post :export, construct_params({ version: 'private' }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('query', :too_long, max_count: ExportHelper::MAX_QUERY_LIMIT, current_count: query.length, element_type: "long query")])
  end

  def test_export_with_empty_query
    params_hash = { ticket_fields: {"display_id":"Ticket ID","subject":"Subject"},
                    contact_fields: { 'name' => 'Requester Name', 'mobile' => 'Mobile Phone' },
                    company_fields: { 'name' => 'Company Name' },
                    format: 'csv',
                    query: "",
                    export_name: "Test export" }
    post :export, construct_params({ version: 'private' }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(:query, :blank)])
  end

  def test_export_with_limit_reach
    export_ids = []
    @account.make_current
    DataExport.archive_ticket_export_limit.times do
      export_entry = @account.data_exports.new(
                            :source => DataExport::EXPORT_TYPE["archive_ticket".to_sym], 
                            :user => User.current,
                            :status => DataExport::EXPORT_STATUS[:started]
                            )
      export_entry.save
      export_ids << export_entry.id
    end
    params_hash = { ticket_fields: {"display_id":"Ticket ID","subject":"Subject"},
                    contact_fields: { 'name' => 'Requester Name', 'mobile' => 'Mobile Phone' },
                    company_fields: { 'name' => 'Company Name' },
                    format: 'csv',
                    query: "priority:1",
                    export_name: "Test export" }
    post :export, construct_params({ version: 'private' }, params_hash)
    assert_response 429
    DataExport.where(:id => export_ids).destroy_all
  end

  def test_export_without_privilege
    User.any_instance.stubs(:privilege?).with(:export_tickets).returns(false)
    params_hash = { ticket_fields: {"display_id":"Ticket ID","subject":"Subject"},
                    contact_fields: { 'name' => 'Requester Name', 'mobile' => 'Mobile Phone' },
                    company_fields: { 'name' => 'Company Name' },
                    format: 'csv',
                    query: "priority:1",
                    export_name: "Test export" }
    post :export, construct_params({ version: 'private' }, params_hash)
    assert_response 403
    User.any_instance.unstub(:privilege?)
  end

  def test_worker_archive_delete_initialise
    stub_archive_assoc_for_show(@archive_association) do
      archive_ticket = @account.archive_tickets.find_by_ticket_id(@archive_ticket.id)
      no_of_jobs = ::Archive::DeleteArchiveTicket.jobs.size
      delete :destroy, controller_params(id: archive_ticket.display_id)
      current_jobs = ::Archive::DeleteArchiveTicket.jobs.size
      assert_equal no_of_jobs + 1, current_jobs
      assert_response 204
    end
  end

  def test_worker_archive_delete_without_ticket
    no_of_jobs = ::Archive::DeleteArchiveTicket.jobs.size
    delete :destroy, controller_params(id: 'q')
    current_jobs = ::Archive::DeleteArchiveTicket.jobs.size
    assert_equal no_of_jobs, current_jobs
    assert_response 404
  end

  def test_delete_without_permission
    stub_archive_assoc_for_show(@archive_association) do
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      no_of_jobs = ::Archive::DeleteArchiveTicket.jobs.size
      archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)
      get :destroy, controller_params(id: archive_ticket.display_id)
      current_jobs = ::Archive::DeleteArchiveTicket.jobs.size
      User.any_instance.unstub(:has_ticket_permission?)
      assert_equal no_of_jobs, current_jobs
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end
  end

  private

    def create_archive_ticket(options = {})
      @account.features.send(:archive_tickets).create
      create_archive_ticket_with_assoc(
        created_at: TICKET_UPDATED_DATE,
        updated_at: TICKET_UPDATED_DATE,
        create_association: true,
        create_twitter_ticket: options[:twitter_ticket] || false,
        tweet_type: options[:twitter_ticket] ? options[:tweet_type] : nil
      )
      @account.archive_tickets.last
    end

    def update_ticket_attributes(pattern, changes = {})
      changes.each do |k, v|
        pattern[k] = v
      end
      pattern
    end

    def exclude_ticket_attributes(pattern, exclude = [])
      exclude.each do |key|
        pattern.except!(key)
      end
      pattern
    end

    def ticket_pattern_for_show(archive_ticket, include_params = nil)
      ticket_pattern = show_ticket_pattern({
                                             cc_emails: archive_ticket.cc_email['cc_emails'],
                                             description: archive_ticket.twitter? ? nil : description_info(archive_ticket)[:description],
                                             description_text: description_info(archive_ticket)[:description_text],
                                             custom_fields: custom_fields(archive_ticket)
                                           }, @archive_ticket)
      ticket_pattern.delete(:source_additional_info)
      changes = {
        created_at: archive_ticket.created_at,
        updated_at: archive_ticket.updated_at,
        archived: true,
        due_by: @archive_ticket.due_by.to_datetime.try(:utc).to_s,
        fr_due_by: @archive_ticket.frDueBy.to_datetime.try(:utc).to_s
      }
      ticket_pattern = update_ticket_attributes(ticket_pattern, changes)
      ticket_pattern = exclude_ticket_attributes(ticket_pattern, EXCLUDE_ATTRIBUTES_FOR_SHOW)
      ticket_pattern[:stats] = ticket_states_pattern(archive_ticket.ticket_states, archive_ticket.status)
      ticket_pattern.merge!(include_json(archive_ticket, include_params)) if include_params.present?
      ticket_pattern[:meta] = construct_meta(archive_ticket) if Account.current.agent_collision_revamp_enabled?

      ticket_pattern
    end

    def construct_meta(ticket)
      {
        secret_id: mask_id(ticket.display_id)
      }
    end

    def include_json(ticket, params)
      final_json = {}
      final_json[:requester] =  requester_hash(ticket) if params.include? :requester
      final_json
    end

    def requester_hash(ticket, options={})
      if CustomRequestStore.read(:private_api_request)
        options[:sideload_options] = ['company'] if @account.multiple_user_companies_enabled?
        requester_hash = ContactDecorator.new(ticket.requester, options).requester_hash
        requester_hash[:language] = ticket.requester.language
        requester_hash[:address] = ticket.requester.address
        requester_hash
      else
        requester_pattern(ticket.requester)
      end
    end

    def custom_fields archive_ticket
      custom_fields_hash = {}
      archive_ticket.custom_field.each do |k,v|
        column = Archive::TicketDecorator.display_name(k)
        custom_fields_hash[column] = v
      end
      custom_fields_hash
    end
end
