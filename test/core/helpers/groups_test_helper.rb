module GroupsTestHelper
  def create_group(account, options = {})
    group = account.groups.find_by_name(options[:name])
    return group if group
    name = options[:name] || "#{Faker::Name.name}_#{Time.now.to_i}"
    group = FactoryGirl.build(:group,:name=> name)
    group.account_id = account.id
    group.group_type = options[:group_type] || GroupConstants::SUPPORT_GROUP_ID
    group.ticket_assign_type  = options[:ticket_assign_type] if options[:ticket_assign_type]
    group.toggle_availability = options[:toggle_availability] if options[:toggle_availability]
    group.save!
    group
  end

  def create_group_with_agents(account, options = {})
    group = account.groups.find_by_name(options[:name])
    return group if group
    name = options[:name] || "#{Faker::Name.name}_#{Time.now.to_i}"
    group = FactoryGirl.build(:group,:name=> name)
    group.account_id = account.id
    group.group_type = options[:group_type] || GroupConstants::SUPPORT_GROUP_ID
    group.ticket_assign_type = options[:ticket_assign_type] if options[:ticket_assign_type]
    options[:agent_list].each { |agent| group.agent_groups.build(:user_id =>agent) } unless options[:agent_list].blank?
    group.save!
    group
  end
end
