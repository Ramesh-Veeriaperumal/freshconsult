class CollabNotificationWorker
  include Sidekiq::Worker
  include ParserUtil

  sidekiq_options queue: :collaboration_publish, retry: 5, dead: true, failures: :exhausted

  GROUP_NOTI_USER_BATCH_SIZE = 30
  HK_GROUP_NOTIFY = 'hk_group_notify'
  HK_NOTIFY = 'hk_notify'

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
      recipient_info.delete(HK_GROUP_NOTIFY)
    end

    return if recipient_info.blank?

    recipient_info = add_user_details(recipient_info)

    if @current_account.group_collab_enabled?
      recipient_info = add_access_tokens(recipient_info)
    end
    message = message_json
    message[:subscriber_properties][:collaboration][:notification_data][:metadata] = recipient_info

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
      recipient_info
    end

    def agents_from_cache
      @agents_from_cache ||= @current_account.agents_details_from_cache
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
