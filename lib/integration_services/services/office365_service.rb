module IntegrationServices::Services
  class Office365Service < IntegrationServices::Service
    include Helpdesk::TicketNotifierHelper
    include Integrations::Office365::AdaptiveCardHelper

     EMAIL_HTML = "<html>
                    <head>
                      <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">
                      <script type=\"application/ld+json\">
                      %{message_card_content}
                      </script>
                    </head>
                    <body>
                      %{hidden_ticket_identifier}
                    </body>
                  </html>"

    def receive_send_email
      begin
        if ticket and ticket.responder.present? and ticket.responder.email.present?
          res = email_resource.send_email(options)
          if res
            Rails.logger.debug "SUCCESS :: Email queued to outlook :: FD account : #{@payload[:act_on_object].account_id} \n #{@payload[:act_on_object].class}/#{@payload[:act_on_object].display_id}"
          end
        else
          Rails.logger.error "FAILURE :: responder Email id not present :: FD account : #{@payload[:act_on_object].account_id} \n #{@payload[:act_on_object].class}/#{@payload[:act_on_object].id}"
        end
      rescue Exception=> e
        Rails.logger.error "Exception while sending email to outlook. \n FD account : #{@payload[:act_on_object].account_id} \n #{@payload[:act_on_object].class}/#{@payload[:act_on_object].id} \n :: #{e.to_s} :: #{e.backtrace.join("\n")}"
        NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => current_account.id, :description => "Exception while sending email to outlook.{acc-#{@payload[:act_on_object].account_id}, -- #{@payload[:act_on_object].class}/#{@payload[:act_on_object].id} : #{e.message}"}})
      end
    end

    private

      def options
        { 
          :recipient => email_id, 
          :reply_email => ticket.reply_email, 
          :subject => title_for_message_card,
          :html => generate_html_content
        }
      end

      def account_name
        account.domain.capitalize
      end

      def title_for_message_card
        "[##{ticket.display_id}] #{ticket.subject}"
      end

      def generate_html_content
        message_card_content = JSON.pretty_generate(generate_message_card_payload).html_safe
        ticket_identifier = hidden_ticket_identifier(ticket)
        adaptive_card_content = JSON.pretty_generate(generate_adaptive_card_payload).html_safe
        format(EMAIL_HTML_ADAPTIVE, adaptive_card_content: adaptive_card_content, message_card_content: message_card_content, hidden_ticket_identifier: ticket_identifier)
      end

      def generate_message_card_payload
        payload = {
          '@context' => 'http://schema.org/extensions',
          "@type" => "MessageCard",
          "hideOriginalBody" => "true",
          "themeColor" => "0072C6",
          "title" => title_for_message_card,
          "text" => trim_message,
          "potentialAction" => generate_potential_action
        }
        payload['originator'] = originator if originator.present?
        payload
      end

      def originator
        Integrations::OFFICE365_ORIGINATOR_ID
      end

      def generate_potential_action
        potential_action_hash = []
        potential_action_hash << potential_action_hash_for_text_input("Add note", "note", "Enter your note.", "Add Private Note")
        potential_action_hash << potential_action_hash_for_multichoice_input("Status", "status", status_hash)
        potential_action_hash << potential_action_hash_for_multichoice_input("Priority", "priority", priority_hash)
        potential_action_hash << potential_action_hash_for_multichoice_input("Agent", "agent", agents_hash)
        potential_action_hash << generate_view_in_fd
        potential_action_hash 
      end

      def generate_multichoice_inputs(id, choices)
        { "@type" => "MultichoiceInput",
          "id" => "#{id}",
          "title" => "Pick an option",
          "choices"=> generate_choices(choices)
        }
      end

      def generate_choices(choices)
        choices_array = []
        choices.each do |k,v|
          choices_array << {"display" => k, "value" => v.to_s}
        end
        choices_array
      end

      def generate_multichoice_actions(id)
        { "@type" => "HttpPOST",
          "name" => "Update",
          "target" => "#{target_url}/#{id}",
          "body" => "{\"ticket_id\":\"#{ticket.id}\",\"#{id}\":\"{{#{id}.value}}\"}",
          "bodyContentType" => "application/json"
        }
      end

      def potential_action_hash_for_multichoice_input(field_name, id, choices)
        field_hash = {"@type" => "ActionCard", "name" => field_name, "inputs" => [], "actions" => []}
        field_hash["inputs"] << generate_multichoice_inputs(id, choices)
        field_hash["actions"] << generate_multichoice_actions(id)
        field_hash
      end

      def potential_action_hash_for_text_input(field_name, id, title, action_name)
        field_hash = {"@type" => "ActionCard", "name" => field_name, "inputs" => [], "actions" => []}
        field_hash["inputs"] << generate_input_for_text_field(id, title)
        field_hash["actions"] << generate_action_for_text_field(action_name, id)
        field_hash
      end

      def generate_input_for_text_field(id, title)
        { "@type" => "TextInput",
          "id"=> id,
          "isMultiline" => true,
          "title"=> title
        }
      end

      def generate_action_for_text_field(action_name, id)
        { "@type"=> "HttpPOST",
          "name"=> action_name,
          "target"=> "#{target_url}/#{id}",
          "body" => "{\"ticket_id\":\"#{ticket.id}\",\"#{id}\":\"{{#{id}.value}}\"}",
          "bodyContentType" => "application/json"
        }
      end

      def generate_view_in_fd
        { "@type" => "OpenUri",
          "name" => "View in Freshdesk",
          "targets" => [
            { "os" => "default", "uri" => ticket_url }
          ]
        }
      end

      def ticket
        @payload[:act_on_object]
      end

      def ticket_url
        "#{account.full_url}/helpdesk/tickets/#{ticket.display_id}"
      end

      def account
        @payload[:act_on_object].account
      end

      def email_id
        @payload[:act_on_object].responder.email
      end

      def status_hash
        statuses = Helpdesk::TicketStatus.status_objects_from_cache(account)
        status_hash = {}
        statuses.each do |s|
         status_hash[s.name] = s.status_id
        end
        status_hash
      end

      def priority_hash
        TicketConstants::PRIORITY_KEYS_BY_NAME
      end

      def agents_hash
        agents = {}
        if ticket.group.present?
          agents = ticket.group.agents.map{|a| [a.email,a.id]}.to_h
        else
          agents = account.agents.map { |a| [a.user.email,a.user.id] }.to_h
        end
        agents 
      end

      def target_url
        "https://#{@payload[:act_on_object].account.full_domain}/integrations/office365"
      end

      def trim_message
        message = parse_message
        message.gsub!("\n","\n\n")
        return message if message.length < 10000
        see_more = "... \n\n **Read more**(#{ticket_url})"
        return (message[1..10000] + see_more)
      end

      def parse_message
        message = @payload[:act_hash][:office365_text]
        ["ticket.description", "ticket.latest_public_comment", "ticket.latest_private_comment"].each do |placeholder|
          message.gsub!("{{#{placeholder}}}","{{#{placeholder}_text}}")
        end
        return "." if message.blank?
        triggered_event = @payload[:triggered_event]
        Liquid::Template.parse(message).render( 'ticket' => ticket, 'helpdesk_name' => ticket.account.portal_name,
                                            'comment' => ticket.notes.visible.exclude_source('meta').last, 'triggered_event' => triggered_event)
      end

      def email_resource
        @email_resource ||= IntegrationServices::Services::Office365::EmailResource.new(self)
      end

  end
end
