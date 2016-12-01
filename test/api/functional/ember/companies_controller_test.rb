require_relative '../../test_helper'
['ticket_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class Ember::CompaniesControllerTest < ActionController::TestCase
  include CompaniesTestHelper
  include SlaPoliciesTestHelper
  include TicketHelper

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account.features.archive_tickets.create
    @@before_all_run = true
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
    company.save!
    company
  end

  def create_archive_tickets(ticket_ids)
    ticket_ids.each do |ticket_id|
      @account.make_current
      Sidekiq::Testing.inline! do
        Archive::BuildCreateTicket.perform_async({ account_id: @account.id, ticket_id: ticket_id })
      end
    end
  end

  def test_index
    rand(2..5).times do
      create_company
    end
    get :index, controller_params(version: 'private')
    assert_response 200
    pattern = []
    Account.current.companies.order(:name).all.each do |company|
      pattern << company_pattern_with_associations({}, company, [])
    end
    match_json(pattern.ordered!)
  end

  def test_index_with_invalid_include_associations
    rand(2..5).times do
      create_company
    end
    invalid_include_list = [Faker::Lorem.word, Faker::Lorem.word]
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
    pattern = []
    Account.current.companies.preload(:user_companies).order(:name).all.each do |company|
      pattern << company_pattern_with_associations({}, company, include_array)
    end
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
    company =  create_company
    get :activities, controller_params(version: 'private', id: company.id, type: Faker::Lorem.word)
    assert_response 400
    match_json([bad_request_error_pattern('type', :not_included, list: 'tickets,archived_tickets')])
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
    pattern = []
    Helpdesk::Ticket.where('display_id IN (?)', ticket_ids).order('created_at desc').each do |ticket|
      pattern << company_activity_pattern(ticket)
    end
    match_json(pattern)
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
    response = parse_response @response.body
    assert_equal 10, response.size
  end

  def test_activities_with_archived_tickets
    company =  create_company
    contact = add_new_user(@account, customer_id: company.id)
    ticket_ids = []
    11.times do
      ticket_ids << create_ticket(requester_id: contact.id).id
    end
    create_archive_tickets(ticket_ids)
    get :activities, controller_params(version: 'private', id: company.id, type: 'archived_tickets')
    assert_response 200
    response = parse_response @response.body
    assert_equal 10, response.size
  end

  def test_show_with_default_sla_policy
    company =  create_company
    get :show, controller_params(version: 'private', id: company.id)
    assert_response 200
    default_policy = Account.current.sla_policies.default
    match_json(company_show_pattern({sla_policies: default_policy}, company))
  end

  def test_show_with_custom_sla_policies
    sla_policy = quick_create_sla_policy
    company_id = sla_policy.conditions[:company_id].first
    get :show, controller_params(version: 'private', id: company_id)
    assert_response 200
    company = Account.current.companies.find(company_id)
    match_json(company_show_pattern({sla_policies: [sla_policy.reload]}, company))
  end
end
