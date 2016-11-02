require_relative '../../test_helper'
class Ember::CompaniesControllerTest < ActionController::TestCase
  include CompaniesTestHelper
  include SlaPoliciesTestHelper

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
    match_json([bad_request_error_pattern('include', :not_included, list: 'contacts_count, sla_policies')])
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

  def test_index_with_sla_policies
    company_sla_hash = {}
    rand(2..5).times do
      sla_policy = quick_create_sla_policy
      company_sla_hash[sla_policy.conditions[:company_id].to_s] = sla_policy.id
    end
    include_array = ['sla_policies']
    get :index, controller_params(version: 'private', include: include_array.join(','))
    assert_response 200
    pattern = []
    sla_policy_hash = {}
    default_policy_id = nil
    Account.current.sla_policies.all.each do |sla|
      sla_policy_hash[sla.id] = sla
      default_policy_id = sla.id if sla.is_default
    end
    Account.current.companies.order(:name).all.each do |company|
      sla_id = company_sla_hash.key?(company.id.to_s) ? company_sla_hash[company.id.to_s] : default_policy_id
      sla_policies = sla_policy_hash[sla_id] ? [sla_policy_hash[sla_id]] : []
      pattern << company_pattern_with_associations({sla_policies: sla_policies}, company, include_array)
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
end
