module IntegrationServices::Services::Slack::Formatter
  class AttachmentFormatter < BaseFormatter

    PRIORITY_COLOUR_MAP = { "1" => "good", #low
                            "2" => "#008FF9", #medium
                            "3" => "warning", #high
                            "4" => "danger", #urgent
    }

    def attachment
      [{
        :fallback => "Activity on - Ticket #{@ticket.display_id} : #{@ticket.subject} - #{ticket_url}",
        :title => "Ticket #{@ticket.display_id}: #{@ticket.subject}",
        :title_link => "#{ticket_url}",
        :color => color_for_priority,
        :fields => [
                  {
                    :title => "Description",
                    :value => "#{ticket_description}",
                  },
                  {
                    :title => "Requester",
                    :value => "#{requester_info}",
                    :short => true
                  },
                  {
                    :title => "Agent",
                    :value =>  "#{agent_info}",
                    :short => true
                  },
                  {
                    :title => "Status",
                    :value => "#{@ticket.status_name}",
                    :short => true
                  },
                  {
                    :title => "Priority",
                    :value => "#{@ticket.priority_name}",
                    :short => true
                  }
              ]
      }].to_json
    end


    private

      def color_for_priority
        PRIORITY_COLOUR_MAP["#{@ticket.priority}"]
      end

      def ticket_description
        @ticket.description.truncate(200)
      end

      def requester_info
        requester = @ticket.requester
        requester_email = @ticket.requester.email
        if requester_email.present?
          slack_id = @requester_slack_id
          return slack_id.present? ? "<@#{slack_id}>" : "#{requester_email}"
        else
          return "https://www.twitter.com/#{requester.twitter_id}" if requester.twitter_id.present?
          return "https://www.facebook.com/#{requester.fb_profile_id}" if requester.fb_profile_id.present?
          return "WorkPhone: #{requester.phone}" if requester.phone.present?
          return "MobilePhone: #{requester.mobile}" if requester.mobile.present?
        end
        return "#{requester.name}"
      end

      def agent_info
        if @ticket.responder.present?
          @agent_slack_id.present? ? "<@#{@agent_slack_id}>" : "#{@ticket.responder.email}"
        else
          I18n.t("integrations.slack_v2.message.no_agent")
        end
      end

      def ticket_url
        Rails.application.routes.url_helpers.helpdesk_ticket_url(@ticket, :host => Account.current.host, :protocol => Account.current.url_protocol)
      end

  end
end