module IntegrationServices::Services::Slack::Processor
  class TicketProcessor

    SLACK_BOT = "USLACKBOT"

    def initialize(payload, installed_app, conversation, users_list, user)
      @payload = payload
      @installed_app = installed_app
      @conversation = conversation
      @users_list = users_list
      @user = user
    end

    def create_ticket
      subject = ticket_subject
      body = ticket_body
      ticket = @installed_app.account.tickets.build(
        :email    => @user.email,
        :priority => TicketConstants::PRIORITY_KEYS_BY_NAME["low"],
        :status   => Helpdesk::Ticketfields::TicketStatus::OPEN, 
        :subject => subject,
        :ticket_body_attributes => {
          :description => body["description"],
          :description_html => "<div>#{body['description_html']}</div>"
        })
        ticket.save_ticket!
        ticket_url(ticket)
    end

    private

      def ticket_subject
        remote_user_id = @payload[:act_hash][:user_id]
        remote_user_name = @payload[:act_hash][:user_name]
        subject_str = "%{body} %{user_name} on #{Time.now.strftime("%a, #{Time.new.day.ordinalize} %b %Y")}"
        @conversation.each do |message|
          user_id = message["user"]
          user_details = user_id.present? ? @users_list[user_id] : nil
          if user_id != remote_user_id && user_id != SLACK_BOT && user_details.present?
            return subject_str % { :body => I18n.t('integrations.slack_v2.subject.chat'), :user_name => user_details[:user_name] }
          end
        end
        subject_str % { :body => I18n.t('integrations.slack_v2.subject.default_chat'), :user_name => remote_user_name }
      end

      #private method
      def ticket_body
        description = ""
        description_html = ""
        @conversation.each do |message|
          if message["text"]
            user_name = user_name_from_message(message)
            message["text"] = message_formatting(message["text"])
            description = description + "#{user_name}" + ": "
            description_html = description_html + "<strong>#{user_name}</strong>" + ": "
            description = description + message["text"] + "\n"
            description_html = description_html + message["text"] + "<br>"
          else
            message["message"]["text"] = message_formatting(message["message"]["text"])
            description = description + message["message"]["text"] + "\n"
            description_html = description_html + message["message"]["text"] + "<br>"
          end
        end
        return {"description" => description, "description_html" => description_html}
      end

      # Verify if this required.
      def message_formatting(text)
        text.gsub!("&","")
        text.gsub!("<","")
        text.gsub!(">","")
        text
      end

      def user_name_from_message message
        user_name = "UnknownUser"
        if message["user"]
          user_id = message["user"]
          user_details = @users_list[user_id]
          user_name = user_details[:user_name] if user_details.present?
        elsif message["username"]
          user_name = message["username"]
        elsif user_id == SLACK_BOT
          user_name = "Slackbot"
        end
        user_name
      end

      def ticket_url(ticket)
        Rails.application.routes.url_helpers.helpdesk_ticket_url(ticket, :host => Account.current.host, :protocol => Account.current.url_protocol)
      end

  end

end