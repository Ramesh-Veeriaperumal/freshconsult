module IntegrationServices::Services::Slack::Formatter
  class MessageFormatter < BaseFormatter

    def text
      message = @payload[:act_hash][:slack_text]
      return "." if message.blank?
      triggered_event = @payload[:triggered_event]
      Liquid::Template.parse(message).render( 'ticket' => @ticket, 'helpdesk_name' => @ticket.account.portal_name,
                                          'comment' => @ticket.notes.last, 'triggered_event' => triggered_event)
    end

  end

end