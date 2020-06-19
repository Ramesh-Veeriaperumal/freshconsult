['shared_ownership_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

module GroupHelper
  include ::SharedOwnershipTestHelper

  def create_group(account, options = {})
    group = account.groups.find_by_name(options[:name])
    return group if group
    name = options[:name] || "#{Faker::Name.name}#{rand(1_000_000)}"
    group = FactoryGirl.build(:group, name: name)
    group.account_id = account.id
    group.group_type = options[:group_type] || GroupConstants::SUPPORT_GROUP_ID
    group.ticket_assign_type = options[:ticket_assign_type] if options[:ticket_assign_type]
    group.toggle_availability = options[:toggle_availability] if options[:toggle_availability]
    group.capping_limit = options[:capping_limit] if options[:capping_limit]
    group.save!
    Account.current.instance_variable_set('@cached_values', {}) if Account.current.present?
    group
  end

  def create_group_with_agents(account, options = {})
    group = account.groups.find_by_name(options[:name])
    return group if group && group.agents.present?
    if group
      add_agent_to_group(group_id = group.id, ticket_permission = 3, role_id = @account.roles.first.id)
    else
      name = options[:name] || "#{Faker::Name.name}#{rand(1_000_000)}"
      group = FactoryGirl.build(:group, name: name)
      group.group_type = options[:group_type] || GroupConstants::SUPPORT_GROUP_ID
      group.account_id = account.id
      group.ticket_assign_type = options[:ticket_assign_type] if options[:ticket_assign_type]
      options[:agent_list].each { |agent| group.agent_groups.build(user_id: agent) } if options[:agent_list].present?
      group.save!
    end
    group
  end

  def create_groups(account, options = { count: 2 })
    groups = []
    options[:count].times do |no|
      group = create_group(account)
      groups << group
    end
    groups
  end

  def create_group_private_api(account, options = {})
    name = "#{Faker::Name.name}#{rand(1_000_000)}"
    group = FactoryGirl.build(:group, name: name)
    group.account_id = account.id
    group.description = Faker::Lorem.paragraph
    group.escalate_to = 1
    group.group_type = options[:group_type] || GroupConstants::SUPPORT_GROUP_ID
    group.agent_ids = options[:agent_ids]
    group.agent_ids = [1, 2] unless options[:agent_ids]
    group.business_calendar_id = 1
    group.ticket_assign_type = options[:ticket_assign_type] if options[:ticket_assign_type]
    group.ticket_assign_type = options[:round_robin_type] if options[:round_robin_type]
    group.capping_limit = options[:capping_limit] if options[:capping_limit]
    group.save!
    group
  end
end
