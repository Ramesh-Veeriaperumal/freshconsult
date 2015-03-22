class Integrations::Slack::SlackUtil 

  include Integrations::Slack::SlackConfigurationsUtil
  include Integrations::Slack::Constant

  def post_to_slack_on_ticket_update(tkt_obj, tkt_data)
    attachment = notificationData(tkt_obj, STATUS_UPDATE)
    notify_slack(attachment, tkt_data)
  end

  def post_to_slack_on_ticket_create(tkt_obj, tkt_data)
    attachment = notificationData(tkt_obj, TICKET_CREATE)
    notify_slack(attachment, tkt_data)
  end

  def post_to_slack_on_note_create(note_obj, tkt_data)
    attachment = notificationData(note_obj, NOTE_CREATE)
    notify_slack(attachment, tkt_data)
  end

  def notificationData(obj, method)
    attachment = {}
    ticket_obj = obj
    if obj.class == Helpdesk::Ticket
      if method == "status_update"
        attachment["pretext"] = "#{I18n.t("integrations.slack_msg.notify_on_ticket_update")}"
        attachment["text"] = "#{I18n.t("integrations.slack_msg.status_msg")}#{obj.status_name}"
      elsif method == "ticket_create"
        requester_name = Account.current.users.find(obj.requester_id).name
        attachment["pretext"] ="#{I18n.t("integrations.slack_msg.notify_on_ticket_create")}#{requester_name}: "
        attachment["text"] = "#{obj.description}"
      end
    elsif obj.class == Helpdesk::Note 
      user = Account.current.users.find(obj.user_id)       
      ticket_obj = obj.notable
      if user.helpdesk_agent
        if obj.private?
          attachment["pretext"] = "#{I18n.t("integrations.slack_msg.notify_on_private_note_create_by_agent")}#{user.name}: "
        else
          attachment["pretext"] = "#{I18n.t("integrations.slack_msg.notify_on_public_note_create_by_agent")}#{user.name}: "  
        end  
      else
        attachment["pretext"] = "#{I18n.t("integrations.slack_msg.notify_on_response_by_customer")}#{user.name}: " 
      end  
      attachment["text"] = "#{obj.body}"
    end

    ticket_details = ticket_details(ticket_obj)
    attachment["fallback"] = "#{attachment['pretext']}Ticket: ##{ticket_details[:id]}"
    attachment["pretext"] = "#{attachment['pretext']}<#{ticket_details[:url]}|Ticket: ##{ticket_details[:id]}>."
    attachment["title"] = "#{ticket_details[:subject]}"
    attachment["title_link"] = "#{ticket_details[:url]}"
    attachment
  end
  
  def ticket_details(tkt_obj)
    ticket = {
      :id       => tkt_obj.display_id.to_s,
      :subject  => tkt_obj.subject,
      :url      => "#{Account.current.full_url}/helpdesk/tickets/#{tkt_obj.display_id.to_s}"
    }
  end

  def installed_app_object
    application_id = Integrations::Application.find_by_name("slack").id
    app_obj        =  Account.current.installed_applications.find_by_application_id(application_id)
  end

  def channels_to_post(tkt_data, app_obj)
    channel_list = []
    status   = tkt_data[:action]
    channels = app_obj.configs[:inputs]["channels"]
    channels.each do |channel|
      channel_list.push(channel["channel_id"]) if channel["actions"].include?status
    end
    channel_list
  end

  def notify_slack(attachment, tkt_data)
    app_obj = installed_app_object
    token = app_obj.configs[:inputs]["oauth_token"]
    channels = channels_to_post(tkt_data,app_obj)
  
    channels.each do |channel| 
      url = "#{SLACK_REST_API[:postMessage]}token=%s&channel=%s&username=%s&icon_url=%s&attachments=[%s]" % [token,channel,USERNAME, ICON_URL,attachment.to_json]
      response = response_handle(url)
  
      if response["ok"]
        Rails.logger.debug "Success in posting message"
      else
        Rails.logger.error "error in posting message to slack #{response.inspect}  and account_id #{app_obj.account_id}"
      end
    end
  end
end
