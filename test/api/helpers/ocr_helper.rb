module OcrHelper
  include UsersHelper

  # groups
  def create_group(account, options = {})
    group = account.groups.find_by_name(options[:name])
    return group if group
    name = options[:name] || Faker::Name.name
		group = FactoryGirl.build(:group, name: name)
		group.account_id = account.id
    group.group_type = options[:group_type] || GroupConstants::SUPPORT_GROUP_ID
		group.ticket_assign_type  = options[:ticket_assign_type] if options[:ticket_assign_type]
    group.toggle_availability = options[:toggle_availability] if options[:toggle_availability]
		group.save!
		group
  end
  
  def group_pattern_for_index_ocr(expected_output = {}, group)
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    {
      id: Fixnum,
      name: (expected_output[:name] || group.name),
      round_robin: GroupConstants::DB_ASSIGNMENT_TYPE_FOR_MAP[group.ticket_assign_type]
    }
  end
  
  def append_header(user_id = nil)
    payload = { source: 'ocr_channel' }
    payload[:actor] = user_id.to_s if user_id.present?
    header =  { alg: "HS256", typ: "JWT" }
    config = CHANNEL_API_CONFIG.fetch('ocr_channel', {})    
    jwt_token = JWT.encode payload, config[:jwt_secret][0], 'HS256', header
    request.env['X-Channel-Auth'] = jwt_token
    request.env['CONTENT_TYPE'] = 'application/json'
  end

  # agents

  def agent_pattern_for_index_ocr(expected_output = {}, agent)
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    {
      id: Fixnum,
      name: expected_output[:name] || agent.name,
      available: expected_output[:available] || agent.available,
      email: expected_output[:email] || agent.user.email
    }
  end

  def agents_groups_pattern_for_index_ocr    
    {
      agent_id: Fixnum,
      group_id: Fixnum      
    }
  end
end
