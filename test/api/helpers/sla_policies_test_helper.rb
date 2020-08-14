['agent_helper.rb','group_helper.rb','products_helper.rb','company_helper.rb', 'sla_policies_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

module SlaPoliciesTestHelper
  include CompanyHelper
  include GroupHelper
  include ProductsHelper
  include SlaPoliciesHelper
  include AgentHelper

  # Patterns
  def sla_policy_pattern(expected_output = {}, sla_policy)
    sla_policy_decorator = SlaPolicyDecorator.new(sla_policy)
    conditions_hash = {}
    conditions_hash = sla_policy_decorator.pluralize_conditions
    sla_target_hash= {}
    sla_target_hash = sla_policy_decorator.pluralize_sla_target
    escalation_hash= {}
    escalation_hash = sla_policy_decorator.pluralize_escalations
    
    {
      id: Fixnum,
      name: sla_policy.name,
      description: sla_policy.description,
      active: sla_policy.active,
      is_default: sla_policy.is_default,
      position: sla_policy_decorator.visual_position,
      sla_target: expected_output[:sla_target] || sla_target_hash,
      applicable_to: expected_output[:applicable_to] || conditions_hash,
      escalation: expected_output[:escalation] || escalation_hash,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def sla_policy_private_pattern(sla_policy)
    {
      id: Fixnum,
      name: sla_policy.name
    }
  end

  def create_complete_sla_policy
    agent = add_agent_to_account(@account, {:name => "testing2",:active => 1, :role => 1} )
    sla_policy = create_sla_policy(agent)
    sla_policy
  end

  def quick_create_sla_policy
    company = create_company
    group = create_group(@account)
    product = create_product
    ticket_type = "Question"
    contact_segment = create_contact_segment
    company_segment = create_company_segment
    sla_policy = FactoryGirl.build(:sla_policies, name: "#{Faker::Lorem.word}#{rand(1_000_000)}", description: Faker::Lorem.paragraph, active: true, account_id: @account.id,

                                                  conditions: { group_id: ["#{group.id}"], company_id: ["#{company.id}"], product_id: ["#{product.id}"], source: ['2'], contact_segment: ["#{contact_segment.id}"], company_segment: ["#{company_segment.id}"] }
                                                  )
    sla_policy.save(validate: false)
    sla_policy
  end

  def create_sla_policy_with_only_company_ids
    company = create_company
    sla_policy = FactoryGirl.build(:sla_policies, name: Faker::Lorem.words, description: Faker::Lorem.paragraph, account_id: @account.id,
                                                  conditions: { company_id: ["#{company.id}"] })
    sla_policy.save(validate: false)
    sla_policy
  end

  def create_sla_params_hash_with_company(private_api_request = false)
    company = create_company
    sla_targets = private_api_request ? create_sla_target_new_format : create_sla_target
    company_ids = private_api_request ? [company.name] : [company.id]
    {name: Faker::Lorem.word,applicable_to:{company_ids: company_ids},sla_target: sla_targets}
  end

  def create_sla_params_hash_with_company_and_product(private_api_request = false)
    company = create_company
    product = create_product
    sla_targets = private_api_request ? create_sla_target_new_format : create_sla_target
    company_ids = private_api_request ? [company.name] : [company.id]
    {name: Faker::Lorem.word,applicable_to:{company_ids: company_ids,product_ids:[product.id]},sla_target: sla_targets}

  end

  def create_sla_target
    { 
      priority_4: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_3: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_2: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true},
      priority_1: { respond_within: 3600,resolve_within: 900,business_hours: false,escalation_enabled: true}
    }
  end

  def create_sla_target_new_format
    {
      priority_4: { first_response_time: "PT1H", resolution_due_time: "PT15M", business_hours: false, escalation_enabled: true },
      priority_3: { first_response_time: "PT1H", resolution_due_time: "PT15M", business_hours: false, escalation_enabled: true },
      priority_2: { first_response_time: "PT1H", resolution_due_time: "PT15M", business_hours: false, escalation_enabled: true },
      priority_1: { first_response_time: "PT1H", resolution_due_time: "PT15M", business_hours: false, escalation_enabled: true }
    }
  end

  def create_sla_policy_with_details(conditions = {}, escalations)
    sla_policy = FactoryGirl.build(:sla_policies, name: Faker::Lorem.words(5), description: Faker::Lorem.paragraph, account_id: @account.id,
                  conditions: { group_id: conditions[:group_id] || ['1']}, 
                  escalations: escalations[:action])
    sla_policy.save(validate: false)
    details = {"4"=>{:level=>"urgent"},"3"=>{:level=>"high"}, "2"=>{:level=>"medium"}, "1"=>{:level=>"low"}}
    details.each_pair do |k,v|
      sla_details = FactoryGirl.build(:sla_details, :name=>"SLA for #{v[:level]} priority", :priority=>"#{k}", :response_time=>"900", :resolution_time=>"900", 
                               :account_id => @account.id, :override_bhrs=>"false", :escalation_enabled=>"1", :sla_policy_id => sla_policy.id)
      sla_details.save(validate: false)
    end
    sla_policy
  end

  def create_contact_segment
    contact_filter = @account.contact_filters.new({name: Faker::Name.name, data: SegmentFiltersTestHelper::CONTACT_FILTER_PARAMS["query_hash"]})
    contact_filter.save!
    contact_filter
  end

  def create_company_segment
    company_filter = @account.company_filters.new({name: Faker::Name.name, data: SegmentFiltersTestHelper::COMPANY_FILTER_PARAMS["query_hash"]})
    company_filter.save!
    company_filter
  end

  def create_custom_source_helper
    source_choice = Helpdesk::Source.new(name: Faker::Name.name, account_id: @account.id, default: 0, deleted: 0)
    source_choice.save!
    source_choice
  end

  # Helpers
  def v2_sla_policy_payload
    sla_policy_params.to_json
  end

  def v1_sla_policy_payload
    { helpdesk_sla_policy: v1_sla_policy_params }.to_json
  end

  # private
  def sla_policy_params
    company_ids = Company.first(2).map(&:id)
    if company_ids.empty?
      2.times { create_company }
      company_ids = Company.first(2).map(&:id)
    end
    { applicable_to: { company_ids: company_ids } }
  end

  def v1_sla_policy_params
    company_ids = Company.first(2).map(&:id).join(',')
    if company_ids.blank?
      2.times do
        create_company
      end
      company_ids = Company.first(2).map(&:id).join(',')
    end
    { conditions: { company_id: company_ids } }
  end
end
