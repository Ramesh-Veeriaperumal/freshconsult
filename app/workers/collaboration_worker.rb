class CollaborationWorker
	include Sidekiq::Worker

  sidekiq_options :queue => 'collaboration_publish', :retry => 5, :dead => true, :failures => :exhausted

  def perform(noti_info)
    current_user = User.current
    current_account = Account.current
    group_collab_enabled = current_account.group_collab_enabled?
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
              :current_domain => current_account.full_domain,
              :message_id => noti_info["mid"],
              :message_body => noti_info["mbody"],
              :mentioned_by_id => current_user.id.to_s,
              :mentioned_by_name => current_user.name,
              :requester_name => ticket.requester[:name],
              :requester_email => ticket.requester[:email],
              :from_address => from_email,
              :metadata => tokenify_recipients(recipient_info, ticket.display_id, group_collab_enabled)
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

  private
  def tokenify_recipients(recipient_info, ticket_display_id, group_collab_enabled)
    collab_ticket = Collaboration::Ticket.new(ticket_display_id)
    if recipient_info["reply"].present?
      recipient_info["reply"]["token"] = group_collab_enabled ? collab_ticket.access_token(recipient_info["reply"]["r_id"]).to_s : ""
    end

    if recipient_info["hk_group_notify"].present?
      for group in recipient_info["hk_group_notify"] do
        for user in group["users"] do
          user["token"] = group_collab_enabled ? collab_ticket.access_token(user["user_id"]).to_s : ""
        end
      end
    end

    if recipient_info["hk_notify"].present?
      for user in recipient_info["hk_notify"] do
        user["token"] = group_collab_enabled ? collab_ticket.access_token(user["user_id"]).to_s : ""
      end
    end
    return recipient_info
  end
end