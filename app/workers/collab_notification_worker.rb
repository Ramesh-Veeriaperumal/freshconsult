class CollabNotificationWorker
  include Sidekiq::Worker
  include ParserUtil

  sidekiq_options queue: :collaboration_publish, retry: 5, dead: true, failures: :exhausted

  GROUP_NOTI_USER_BATCH_SIZE = 30
  HK_GROUP_NOTIFY = 'hk_group_notify'.freeze
  HK_NOTIFY = 'hk_notify'.freeze
  FOLLOWER_NOTIFY = 'follower_notify'.freeze

  def perform(noti_info)
    @noti_info = noti_info
    @current_user = User.current
    @current_account = Account.current
    @ticket = @current_account.tickets.find_by_display_id(@noti_info['ticket_display_id'])

    return if @ticket.blank?

    begin
      recipient_info = JSON.parse(@noti_info['metadata'])
    rescue JSON::ParserError => e
      raise e, "Invalid JSON string: #{recipient_info}"
    end

    return if recipient_info.blank?

    if recipient_info[HK_GROUP_NOTIFY].present?
      send_group_notification(recipient_info)
      if recipient_info[FOLLOWER_NOTIFY].present?
        recipient_info = add_group_info_for_followers(recipient_info)
      end
      recipient_info.delete(HK_GROUP_NOTIFY)
    end

    return if recipient_info.blank?

    recipient_info = add_user_details(recipient_info)

    if @current_account.group_collab_enabled?
      recipient_info = add_access_tokens(recipient_info)
    end
    message = message_json
    message[:subscriber_properties][:collaboration][:notification_data][:metadata] = recipient_info

    if recipient_info[FOLLOWER_NOTIFY].present?
      message = add_additional_follower_notification_details(message)
    end

    sqs_resp = AwsWrapper::SqsV2.send_message(SQS[:collab_ticket_update_queue], message.to_json)
    Rails.logger.info "Collab: SQS: notification resp: #{sqs_resp[:message_id]}"
  end

  private

  def message_json
    from_info = parse_email(@ticket.selected_reply_email) || parse_email(@current_account.default_friendly_email)
    {
      object: 'user_notification',
      account_id: @ticket.account_id,
      ticket_properties: {
        id: @ticket.id,
        display_id: @ticket.display_id,
        subject: @ticket.subject,
        account_id: @ticket.account_id
      },
      subscriber_properties: {
        collaboration: {
          notification_data: {
            client_id: Collaboration::Ticket::HK_CLIENT_ID,
            current_domain: @noti_info['current_domain'],
            message_id: @noti_info['mid'],
            message_body: @noti_info['mbody'],
            mentioned_by_id: @current_user.id.to_s,
            mentioned_by_name: @current_user.name,
            requester_name: @ticket.requester[:name],
            requester_email: @ticket.requester[:email],
            from_data: from_info
          }
        }
      }
    }
  end

  def add_user_details(recipient_info)
    if recipient_info['reply'].present?
      reply_to = agents_from_cache.find { |agent| recipient_info['reply']['r_id'] == agent.id.to_s }
      recipient_info['reply'].merge!({ 'name' => reply_to.name, 'email' => reply_to.email }) if reply_to.present?
    end

    if recipient_info[HK_NOTIFY].present?
      user_noti_data = []
      recipient_info[HK_NOTIFY].each do |user|
        noti_user = agents_from_cache.find { |agent| user['user_id'] == agent.id.to_s }
        user_noti_data << {
          'user_id' => user['user_id'],
          'name' => noti_user.name,
          'email' => noti_user.email,
          'invite' => user['invite']
        } if noti_user.present?
      end
      recipient_info[HK_NOTIFY] = user_noti_data
    end

    if recipient_info[FOLLOWER_NOTIFY].present?
      follower_noti_data = []
      recipient_info[FOLLOWER_NOTIFY].each do |follower|
        noti_follower = agents_from_cache.find { |agent| follower['follower_id'] == agent.id.to_s }
        next unless noti_follower.present?
        follower_data = {}
        follower_data.merge!(
          follower_id: follower['follower_id'],
          name: noti_follower.name,
          email: noti_follower.email
        )
        follower_data[:group_ids] = follower['group_ids'] if follower.key?('group_ids')
        follower_noti_data << follower_data
      end
      recipient_info[FOLLOWER_NOTIFY] = follower_noti_data
    end
    recipient_info
  end

  def add_additional_follower_notification_details(message)
    topmembers_info = []
    begin
      topmembers_info = JSON.parse(@noti_info['top_members'])
    rescue JSON::ParserError => e
      raise e, "Invalid JSON string: #{topmembers_info}"
    end
    notiUpdates = {}
    if topmembers_info.any?
      topmembers_info = add_top_members_details(topmembers_info)
      notiUpdates.merge!({:top_members => topmembers_info})
    end
    sender_imgurl = user_image_url(@noti_info['current_domain'], @current_user)
    notiUpdates.merge!(
      {:message_sender_imgurl => sender_imgurl,
       :message_type => @noti_info['m_type'],
       :message_ts => @noti_info['m_ts']
       })
    message[:subscriber_properties][:collaboration][:notification_data].merge!(notiUpdates)
    message
  end

  def add_top_members_details(topmembers_info)
    top_members_data = []
    topmembers_info.each do |member|
      top_member = agents_from_cache.find {|agent| member['member_id'] == agent.id.to_s}
      imgUrl = user_image_url(@noti_info['current_domain'], top_member)
      top_members_data << {
        'member_name' => top_member.name,
        'member_img_url' => imgUrl
      } if top_member.present?
    end
    top_members_data
  end

  def add_group_info_for_followers(recipient_info)
    @mentioned_groups = @current_account.groups_from_cache.select { |grp| recipient_info[HK_GROUP_NOTIFY].include?(grp.id) }
    @mentioned_groups.each do |group_info|
      @group_users_map = agents_for_groups(recipient_info[HK_GROUP_NOTIFY])
      @group_users_map[group_info.id].each do |user|
        follower_noti_data = []
        recipient_info[FOLLOWER_NOTIFY].each do |follower|
          if follower['follower_id'] == user[:id].to_s
            groups_ids = follower['group_ids'] || []
            groups_ids << group_info.id.to_s
            follower['group_ids'] = groups_ids
          end
          follower_noti_data << follower
        end
        recipient_info[FOLLOWER_NOTIFY] = follower_noti_data
      end
    end
    recipient_info
  end

  def batchify_groups(recipient_info)
    group_batch = []
    @mentioned_groups = @current_account.groups_from_cache.select { |grp| recipient_info[HK_GROUP_NOTIFY].include?(grp.id) }
    @mentioned_groups.each do |group_info|
      group_users_wrapper = {
        'group_id' => group_info.id,
        'group_name' => group_info.name,
        'users' => []
      }

      user_batch = []
      counter = 0

      @group_users_map = agents_for_groups(recipient_info[HK_GROUP_NOTIFY])

      @group_users_map[group_info.id].each do |user|
        next if @current_user.id == user[:id]
        counter += 1
        if (counter > GROUP_NOTI_USER_BATCH_SIZE)
          counter = 1
          group_users_wrapper['users'] << user_batch
          user_batch = []
        end
        user_batch << {
          'user_id' => user[:id].to_s,
          'name' => user[:name],
          'email' => user[:email]
        }
      end
      group_users_wrapper['users'] << user_batch
      user_batch = []
      group_batch << group_users_wrapper
    end

    group_batch
  end

  def send_group_notification(recipient_info)
    groups_list = batchify_groups(recipient_info)
    groups_list = add_access_tokens({ HK_GROUP_NOTIFY => groups_list })[HK_GROUP_NOTIFY] if @current_account.group_collab_enabled?

    message = message_json
    groups_list.each do |group|
      group['users'].each do |users_batch_list|
        next unless users_batch_list.present?

        message[:subscriber_properties][:collaboration][:notification_data][:metadata] = {
          HK_GROUP_NOTIFY => [{
                                'group_id' => group['group_id'],
                                'group_name' => group['group_name'],
                                'users' => users_batch_list
          }]
        }

        sqs_resp = AwsWrapper::SqsV2.send_message(SQS[:collab_ticket_update_queue], message.to_json)
        Rails.logger.info "Collab: SQS: group notification: #{sqs_resp[:message_id]}"
      end
    end
  end

  def add_access_tokens(recipient_info)
    collab_ticket = Collaboration::Ticket.new(@ticket.display_id)
    if recipient_info['reply'].present?
      recipient_info['reply']['token'] = collab_ticket.access_token(recipient_info['reply']['r_id']).to_s
    end

    if recipient_info[HK_GROUP_NOTIFY].present?
      recipient_info[HK_GROUP_NOTIFY].each do |group|
        group['users'].each do |batch|
          batch.each do |user|
            user['token'] = collab_ticket.access_token(user['user_id'], group['group_id']).to_s
          end
        end
      end
    end

    if recipient_info[HK_NOTIFY].present?
      recipient_info[HK_NOTIFY].each do |user|
        user['token'] = collab_ticket.access_token(user['user_id']).to_s
      end
    end

    if recipient_info[FOLLOWER_NOTIFY].present?
      recipient_info[FOLLOWER_NOTIFY].each do |follower|
        follower['token'] = collab_ticket.access_token(follower['follower_id']).to_s
      end
    end
    recipient_info
  end

  def agents_from_cache
    @agents_from_cache ||= @current_account.agents_details_ar_from_cache
  end

  def agents_for_groups(group_ids)
    group_hash = {}
    group_ids.each do |grp_id|
      group_hash[grp_id] = group_agents_from_cache[grp_id]
    end
    group_hash
  end

  def group_agents_from_cache
    @group_agents ||= map_group_agents
  end

  def user_image_url(current_domain, user)
    (user.present? && user.avatar.present?) ? "#{current_domain}/users/#{user.id}/profile_image_no_blank" : ""
  end

  def map_group_agents
    group_agents = {}
    @current_account.agent_groups_from_cache.each do |ag|
      group_agents[ag.group_id] = group_agents[ag.group_id] || []
      agent = agents_from_cache.find { |afc| ag.user_id == afc.id }
      group_agents[ag.group_id] << {
        id:  agent.id,
        name: agent.name,
        email: agent.email
      } if agent.present?
    end
    group_agents
  end
end
