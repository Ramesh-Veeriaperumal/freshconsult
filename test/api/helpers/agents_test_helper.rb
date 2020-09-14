['group_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module AgentsTestHelper
  include GroupHelper
  include Gamification::GamificationUtil
  AVAILABILITY_COUNT_RESPONSE = {
    'agents_availability_count': {
      'freshdesk': 10,
      'freshchat': 7,
      'freshcaller': 5
    }
  }.freeze
  def agent_pattern(expected_output = {}, agent)
    user = {
      active: agent.user.active,
      created_at: agent.user.created_at,
      email: agent.user.email,
      job_title: expected_output['job_title'] || agent.user.job_title,
      language: expected_output['language'] || agent.user.language,
      last_login_at: agent.user.last_login_at.try(:utc).try(:iso8601),
      mobile: expected_output['mobile'] || agent.user.mobile,
      name: agent.user.name,
      phone: agent.user.phone,
      time_zone: agent.user.time_zone,
      updated_at: agent.user.updated_at
    }
    agent_hash = {
      available_since: expected_output[:available_since] || agent.active_since,
      available: expected_output[:available] || agent.available,
      created_at: agent.created_at,
      id: Fixnum,
      occasional: expected_output[:occasional] || agent.occasional,
      signature: expected_output[:signature_html] || agent.signature_html,
      ticket_scope: expected_output[:ticket_scope] || agent.ticket_permission,
      updated_at: agent.updated_at,
      last_active_at: agent.last_active_at,
      contact: expected_output[:user] || user,
      type: Account.current.agent_types_from_cache.find { |type| type.agent_type_id == agent.agent_type }.name
    }
    if Account.current.freshcaller_enabled?
      agent_hash[:freshcaller_agent] = agent.freshcaller_agent.present? ? agent.freshcaller_agent.try(:fc_enabled) : false
    end
    agent_hash[:freshchat_agent] = agent.additional_settings.try(:[], :freshchat).try(:[], :enabled) || false if Account.current.omni_chat_agent_enabled?
    agent_hash[:agent_level_id] = agent.scoreboard_level_id if Account.current.gamification_enabled? && Account.current.gamification_enable_enabled?
    agent_hash[:availability] = expected_output[:availability] if expected_output[:availability].present?
    agent_hash
  end

  def private_api_agent_pattern(expected_output = {}, agent)
    {

      available: expected_output[:available] || agent.available,
      show_rr_toggle: expected_output[:show_rr_toggle] || agent.toggle_availability?,
      latest_notes_first: expected_output[:latest_notes_first] || Account.current.latest_notes_first_enabled?(agent.user),
      occasional: expected_output[:occasional] || agent.occasional,
      id: Fixnum,
      ticket_scope: expected_output[:ticket_scope] || agent.ticket_permission,
      signature: expected_output[:signature_html] || agent.signature_html,
      role_ids: expected_output[:role_ids] || agent.user.role_ids,
      skill_ids: expected_output[:skill_ids] || agent.user.skill_ids,
      group_ids: expected_output[:group_ids] || agent.group_ids,
      available_since: expected_output[:available_since] || agent.active_since,
      contact: contact_pattern(expected_output[:user] || agent.user),
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      last_active_at: expected_output[:last_active_at] || agent.last_active_at.try(:utc).try(:iso8601),
      gdpr_admin_name: expected_output[:gdpr_admin_name] || agent.user.current_user_gdpr_admin,
      type: Account.current.agent_types_from_cache.find { |type| type.agent_type_id == agent.agent_type }.name,
      read_only: agent.user.privilege?(:manage_account)
    }
  end

  def private_api_omni_channel_availability_pattern(expected_output = {}, agent)
    agent_hash = private_api_agent_pattern(agent)
    agent_hash.merge!(availability: expected_output[:availability]) if expected_output[:availability].present?
  end

  def private_api_privilege_agent_pattern(user)
    {
      id: user.id,
      contact: {
        name: user.name,
        email: user.email
      }
    }
  end

  def private_api_restriced_agent_hash(expected_output ={}, agent)
    {
      id: Fixnum,
      contact: restricted_agent_contact_pattern(expected_output[:user] || agent.user),
      group_ids: expected_output[:group_ids] || agent.group_ids,
      type: AgentType.agent_type_name(agent.agent_type)
    }
  end

  def agent_availability_pattern(expected_output = {}, agent, rr_groups)
    agent_hash = private_api_agent_pattern(agent)
    agent_hash.merge!(agent_availability_hash(agent.group_ids, rr_groups))
  end

  def agent_availability_hash(group_ids, rr_groups)
    rr_agent = ((rr_groups || []) & (group_ids || [])).present?
    return {} unless rr_agent
    {
      ticket_assignment: {
        available: false,
        round_robin_agent: rr_agent
      }
    }
  end

  def agent_availability_count_pattern
    {
      agents: [
      ],
      meta: {
        agents_available: {
          ticket_assignment: 0
        }
      }
    }
  end

  def agent_achievements_pattern(record)
    achievements_hash = {}
    if gamification_feature?(Account.current)
      next_level = record.next_level || Account.current.scoreboard_levels.next_level_for_points(record.points.to_i).first
      points_needed = 0
      points_needed = next_level.points - record.points.to_i if next_level
      achievements_hash = {
        id: record.user_id,
        points: record.points.to_i,
        current_level_name: record.level.try(:name),
        next_level_name: next_level.try(:name),
        points_needed: points_needed,
        badges: record.user.quests.order('achieved_quests.created_at Desc').map(&:badge_id)
      }
    end
    achievements_hash
  end

  def livechat_agent_availability(agent)
    [ agent.user.id,
      {
        "agent_id" => agent.user.id,
        "last_activity_at"=> nil,
        "available"=> false,
        "onGoingChatCount"=> 0
      }
    ]
  end

  def contact_pattern(contact)
    {
      active: contact.active,
      email: contact.email,
      job_title: contact.job_title,
      language: contact.language,
      mobile: contact.mobile,
      name: contact.name,
      phone: contact.phone,
      time_zone: contact.time_zone,
      avatar: get_contact_avatar(contact)
    }
  end

  def restricted_agent_contact_pattern(contact)
    {
      name: contact.name,
      email: contact.email,
    }
  end 

  def get_contact_avatar(contact)
    return nil unless contact.avatar
    {
      content_type: contact.avatar.content_content_type,
      size: contact.avatar.content_file_size,
      name: contact.avatar.content_file_name,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      id: contact.avatar.id,
      attachment_url: String,
      thumb_url: String
    }
  end

  def agent_pattern_with_additional_details(expected_output = {}, agent_user)
    user = {
      active: agent_user.active,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      email: expected_output[:email] || agent_user.email,
      job_title: expected_output[:job_title] || agent_user.job_title,
      language: expected_output[:language] || agent_user.language,
      last_login_at: agent_user.last_login_at.try(:utc).try(:iso8601),
      mobile: expected_output[:mobile] || agent_user.mobile,
      name: expected_output[:name] || agent_user.name,
      phone: expected_output[:phone] || agent_user.phone,
      time_zone: expected_output[:time_zone] || agent_user.time_zone,
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    agent = agent_user.agent
    agent_hash = {
      available_since: expected_output[:available_since] || agent.active_since,
      available: expected_output[:available] || agent.available,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      id: Fixnum,
      occasional: expected_output[:occasional] || agent.occasional,
      signature: expected_output[:signature] || agent.signature_html,
      ticket_scope: expected_output[:ticket_scope] || agent.ticket_permission,
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      role_ids: expected_output[:role_ids] || agent_user.role_ids,
      skill_ids: expected_output[:skill_ids] || agent_user.skill_ids,
      group_ids: expected_output[:group_ids] || agent.group_ids,
      contact: expected_output[:user] || user,
      type: Account.current.agent_types_from_cache.find { |type| type.agent_type_id == agent.agent_type }.name,
      last_active_at: expected_output[:last_active_at] || agent.last_active_at.try(:utc).try(:iso8601)
    }
    if Account.current.freshcaller_enabled?
      agent_hash[:freshcaller_agent] = agent.freshcaller_agent.present? ? agent.freshcaller_agent.try(:fc_enabled) : false
    end
    if Account.current.advanced_ticket_scopes_enabled?
      agent_hash[:contribution_group_ids] = expected_output[:contribution_group_ids] || agent.contribution_group_ids
    end
    agent_hash[:freshchat_agent] = agent.additional_settings.try(:[], :freshchat).try(:[], :enabled) || false if Account.current.omni_chat_agent_enabled?
    agent_hash[:agent_level_id] = agent.scoreboard_level_id if Account.current.gamification_enabled? && Account.current.gamification_enable_enabled?
    agent_hash
  end

  def availability_count_pattern(availability_count_response = AVAILABILITY_COUNT_RESPONSE)
    OmniChannelRouting::Constants::OMNI_CHANNELS.each_with_object([]) do |channel, array|
      array << { channel: channel, count: availability_count_response[:agents_availability_count][channel.to_sym] || 0 }
    end
  end

  def profile_agent_pattern_with_additional_details(agent_user, expected_output = {})
    agent_pattern_with_additional_details(expected_output, agent_user).except(:last_active_at)
  end

  def v2_agent_payload
    role_ids = Role.limit(2).pluck(:id)
    group_ids = [create_group(@account).id]
    params = { name: Faker::Name.name, phone: Faker::PhoneNumber.phone_number, mobile: Faker::PhoneNumber.phone_number, email: Faker::Internet.email, time_zone: 'Central Time (US & Canada)', language: 'hu', occasional: false, signature: Faker::Lorem.paragraph, ticket_scope: 2,
               role_ids: role_ids, job_title: Faker::Name.name }
    params.to_json
  end

  def v1_agent_payload
    role_ids = Role.limit(2).pluck(:id).join(',')
    params = { agent: { user: { name: Faker::Name.name, phone: Faker::PhoneNumber.phone_number, job_title: Faker::Name.name, mobile: Faker::PhoneNumber.phone_number, email: Faker::Internet.email, time_zone: 'Central Time (US & Canada)', language: 'hu', role_ids: role_ids }, occasional: false, signature_html: Faker::Lorem.paragraph, ticket_permission: 2 } }
    params.to_json
  end

  def create_rr_agent
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    group = create_group_with_agents(@account, agent_list: [agent.id])
    group.ticket_assign_type = 1
    group.save
    @account.chat_setting.enabled = true
    @account.save
  end

  def failure_pattern(failures = {})
    failures.map do |rec_email, errors|
      {
        email: rec_email,
        errors: errors.map do |field, value|
          agent_bad_request_error_pattern(field, *value)
        end,
        error_options: {}
      }
      end
  end

  def agent_bad_request_error_pattern(field, value, params_hash = {})
    code = params_hash[:code] || ErrorConstants::API_ERROR_CODES_BY_VALUE[value] || ErrorConstants::DEFAULT_CUSTOM_CODE
    message = retrieve_message(params_hash[:prepend_msg]) + retrieve_message(value) + retrieve_message(params_hash[:append_msg])
    {
      code: code,
      field: "#{field}",
      nested_field: nil,
      http_code: ErrorConstants::API_HTTP_ERROR_STATUS_BY_CODE[code] || ErrorConstants::DEFAULT_HTTP_CODE,
      message: message % params_hash
    }
  end
  
  def freshid_user(freshid_user_params = {})
    freshid_user_params.merge!({uuid: SecureRandom.uuid, status: "ACTIVATED"})
    Freshid::User.new(freshid_user_params)
  end

  def private_api_search_in_freshworks_pattern(user, expected_output = {})
    {
      freshid_user_info: {
        name: expected_output[:name] || user.name,
        phone: expected_output[:phone] || user.phone,
        mobile: expected_output[:mobile] || user.mobile,
        job_title: expected_output[:job_title] || user.job_title
      },
      user_info: expected_output[:user_info]
    }
  end

  def agents_count_key
    format(Redis::Keys::Others::AGENTS_COUNT_KEY, account_id: Account.current.id.to_s)
  end

  def update_user_created_at(email, time)
    user = User.find_by_email(email)
    user.created_at = time
    user.save!
  end

  def update_agent_last_activet_at(email, time)
    user = User.find_by_email(email)
    user.agent.last_active_at = time
    user.agent.save!
  end

  def generate_time_at_interval(frequency, day_interval)
    time = []
    datetime = Time.now.utc
    frequency.times do
      datetime += day_interval.day
      time.push(datetime.to_s(:db))
    end
    time
  end

  def check_agents_order(user_order, response)
    assert_response 200
    current_response = parse_response response.body
    assert user_order.size.to_s, current_response.size.to_s
    user_order.each_with_index do |element, index|
      assert element.name, current_response[index]['contact']['name']
    end
  end

  def ocr_agents_response(agent_data)
    count = 0
    ocr_agents = agent_data[:channel].each_with_object([]) do |(key, val), agents|
      count += 1
      each_agent = {
        id: Faker::Number.number(7),
        name: agent_data[:name],
        on_call: val[:freshcaller][:on_call],
        freshdesk_user_id: key,
        freshdesk_availability: val[:freshdesk][:available],
        freshdesk_task_limit: val[:freshdesk][:assignment_limit],
        freshdesk_availability_updated_at: val[:freshdesk][:availability_updated_at],
        freshchat_user_id: Faker::Lorem.characters(5),
        freshchat_status: val[:freshchat][:logged_in],
        freshchat_preference: val[:freshchat][:available],
        freshchat_task_limit: val[:freshchat][:assignment_limit],
        freshchat_availability_updated_at: val[:freshchat][:availability_updated_at],
        freshcaller_user_id: Faker::Lorem.characters(5),
        freshcaller_status: val[:freshcaller][:logged_in],
        freshcaller_preference: val[:freshcaller][:available],
        freshcaller_task_limit: val[:freshcaller][:assignment_limit],
        freshcaller_availability_updated_at: val[:freshcaller][:availability_updated_at],
        freshdesk_round_robin: val[:freshdesk][:round_robin_enabled],
        freshchat_round_robin: val[:freshchat][:round_robin_enabled],
        freshcaller_round_robin: val[:freshcaller][:round_robin_enabled],
        status_id: agent_data[:status_id]
      }
      agents << each_agent
    end
    { meta: { count: count }, ocr_agents: ocr_agents }.to_json
  end

  def ocr_agent_availability_reformat(channels_data)
    channels_data.each_with_object([]) do |(key, value), output|
      output << value.merge!(channel: key)
    end
  end

  def ocr_agents_availability_pattern(output)
    [{ id: output[:id], contact: { name: output[:name] }, availability: { status: { id: output[:status_id] }, channel_availability: output[:availability] } }]
  end

  def mars_agents_response
    {
      agents: [{
        id: Faker::Lorem.characters(5),
        contact: {
          name: Faker::Lorem.characters(5),
          email: Faker::Internet.email
        },
        availability: {
          channel_availability:
          [
            {
              channel: 'freshdesk',
              available: true,
              assignment_limit: 10,
              availability_updated_at: Faker::Time.between(10.days.ago, 2.days.ago)
            },
            {
              channel: 'freshchat',
              available: true,
              assignment_limit: 3,
              availability_updated_at: Faker::Time.between(10.days.ago, 2.days.ago),
              logged_in: true
            },
            {
              channel: 'freshcaller',
              available: true,
              assignment_limit: 1,
              availability_updated_at: Faker::Time.between(10.days.ago, 2.days.ago),
              logged_in: true,
              on_call: true
            }
          ]
        }
      }],
      meta: {
        count: 1
      }
    }.to_json
  end
end
