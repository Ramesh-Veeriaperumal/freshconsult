['company_helper.rb', 'sla_policies_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module SlaPoliciesTestHelper
  include CompanyHelper
  include SlaPoliciesHelper

  # Patterns
  def sla_policy_pattern(expected_output = {}, sla_policy)
    conditions_hash = {}
    sla_policy.conditions.each { |key, value| conditions_hash[key.to_s.pluralize] = value } unless sla_policy.conditions.nil?
    {
      id: Fixnum,
      name: sla_policy.name,
      description: sla_policy.description,
      is_default: sla_policy.is_default,
      applicable_to: expected_output[:applicable_to] || conditions_hash,
      position: sla_policy.position,
      active: sla_policy.active,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def quick_create_sla_policy
    company = create_company
    sla_policy = FactoryGirl.build(:sla_policies, name: Faker::Lorem.words(5), description: Faker::Lorem.paragraph, account_id: @account.id,
                                                  conditions: { group_id: ['1'], company_id: ["#{company.id}"] })
    sla_policy.save(validate: false)
    sla_policy
  end

  def create_sla_policy_with_only_company_ids
    company = create_company
    sla_policy = FactoryGirl.build(:sla_policies, name: Faker::Lorem.words(5), description: Faker::Lorem.paragraph, account_id: @account.id,
                                                  conditions: { company_id: ["#{company.id}"] })
    sla_policy.save(validate: false)
    sla_policy
  end

  def create_sla_policy_with_escalations(conditions = {}, escalations = {})
    sla_policy = FactoryGirl.build(:sla_policies, name: Faker::Lorem.words(5), description: Faker::Lorem.paragraph, account_id: @account.id,
                                                  conditions: { group_id: conditions[:group_id] || ['1']}, 
                                                  escalations: { 
                                                      reminder_response: {
                                                        "1" => { :time => escalations[:time] || -1800, :agents_id => escalations[:agent_ids] || [-1] }
                                                      },
                                                      reminder_resolution: {
                                                        "1" => { :time => escalations[:time] || -1800, :agents_id => escalations[:agent_ids] || [-1] }
                                                      }
                                                    })
    sla_policy.save
    sla_policy
  end

  def create_sla_policy_with_details(conditions = {}, escalations = {}, ticket_priority = 1)
    sla_policy = FactoryGirl.build(:sla_policies, name: Faker::Lorem.words(5), description: Faker::Lorem.paragraph, account_id: @account.id,
                                                  conditions: { group_id: conditions[:group_id] || ['1']}, 
                                                  escalations: { 
                                                      response: {
                                                        "1" => { :time => escalations[:time] || -1800, :agents_id => escalations[:agent_ids] || [-1] }
                                                      },
                                                      resolution: {
                                                        "1" => { :time => escalations[:time] || -1800, :agents_id => escalations[:agent_ids] || [-1] }
                                                      }
                                                    })
    sla_policy.save(validate: false)
    sla_details = FactoryGirl.build(:sla_details, name: "SLA for ticket priority", priority: ticket_priority, 
                                              response_time: 900, resolution_time: 900, sla_policy_id: sla_policy.id,
                                              account_id: @account.id, escalation_enabled: true)
    sla_details.save
    sla_policy
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
