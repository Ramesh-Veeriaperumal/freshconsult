class CollaborationWorker
	include Sidekiq::Worker

  sidekiq_options :queue => 'collaboration_publish', :retry => 5, :dead => true, :failures => :exhausted

  def perform(noti_info)
    current_user = User.current
    current_account = Account.current
    ticket = current_account.tickets.find_by_display_id(noti_info["ticket_display_id"])

    if ticket.present?
      from_email = ticket.selected_reply_email.scan( /<([^>]*)>/).to_s
      if from_email.blank?
        from_email = current_account.default_friendly_email.scan( /<([^>]*)>/).to_s
      end

      begin
        recipient_info = JSON.parse(noti_info["metadata"])
      rescue JSON::ParserError => e
        raise e, "Invalid JSON string: #{recipient_info}"
      end

      recipient_info = add_user_details(recipient_info)

      if current_account.group_collab_enabled?
          recipient_info = tokenify_recipients(recipient_info, ticket.display_id)
      end 

      message = {
        :object => "user_notification",
        :account_id => ticket.account_id,
        :ticket_properties => {
          id: ticket.id,
          display_id: ticket.display_id,
          subject: ticket.subject,
          account_id: ticket.account_id
        }, 
        :subscriber_properties => {
          :collaboration => {
            :notification_data => {
              :client_id => Collaboration::Ticket::HK_CLIENT_ID,
              :current_domain => noti_info["current_domain"],
              :message_id => noti_info["mid"],
              :message_body => noti_info["mbody"],
              :mentioned_by_id => current_user.id.to_s,
              :mentioned_by_name => current_user.name,
              :requester_name => ticket.requester[:name],
              :requester_email => ticket.requester[:email],
              :from_address => from_email,
              :metadata => recipient_info
            }
          }
        }
      }

      sqs_resp = AwsWrapper::SqsV2.send_message(SQS[:collab_ticket_update_queue], message.to_json)
      puts "Pushed notification message to SQS for collab. #{sqs_resp[:message_id]}"
    else
      puts "Notification message push for collab failed. info: #{noti_info}"
    end
  end

  def add_user_details(recipient_info)
    current_account = Account.current
    current_user = User.current
    if recipient_info["reply"].present?
      reply_to = current_account.users.find_by_id(recipient_info["reply"]["r_id"])
      recipient_info["reply"].merge!({
        "name" => reply_to.name,
        "email" => reply_to.email
      })
    end

    if recipient_info["hk_group_notify"].present?
      group_noti_data = []
      for group_id in recipient_info["hk_group_notify"] do
        noti_group = Group.find_by_id(group_id)
        group_info = {
          "group_id" => group_id,
          "group_name" => noti_group.name,
          "users" => []
        }
        for user in noti_group.agents do
          if current_user.id != user.id
            group_info["users"] << {
              "user_id" => user.id.to_s,
              "name" => user.name,
              "email" => user.email,
            }
          end
        end
        group_noti_data << group_info
      end
      recipient_info["hk_group_notify"] = group_noti_data
    end

    if recipient_info["hk_notify"].present?
      user_noti_data = []
      for user in recipient_info["hk_notify"] do
        noti_user = current_account.users.find_by_id(user["user_id"]) 
        user_noti_data << {
          "user_id" => user["user_id"],
          "name" => noti_user.name,
          "email" => noti_user.email,
          "invite" => user["invite"]
        }
      end
      recipient_info["hk_notify"] = user_noti_data
    end
    recipient_info
  end

  private
  def tokenify_recipients(recipient_info, ticket_display_id)
    collab_ticket = Collaboration::Ticket.new(ticket_display_id)
    if recipient_info["reply"].present?
      recipient_info["reply"]["token"] = collab_ticket.access_token(recipient_info["reply"]["r_id"]).to_s
    end

    if recipient_info["hk_group_notify"].present?
      for group in recipient_info["hk_group_notify"] do
        for user in group["users"] do
          user["token"] = collab_ticket.access_token(user["user_id"], group["group_id"]).to_s
        end
      end
    end

    if recipient_info["hk_notify"].present?
      for user in recipient_info["hk_notify"] do
        user["token"] = collab_ticket.access_token(user["user_id"]).to_s
      end
    end
    recipient_info
  end
end