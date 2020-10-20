class Fixtures::DefaultFeedbackWidgetTicket < Fixtures::DefaultTicket

  private

    def priority
      TicketConstants::PRIORITY_KEYS_BY_TOKEN[:low]
    end

    def source
      Helpdesk::Source::FEEDBACK_WIDGET
    end

    def type
      #REVISIT . Need to change this after ticket constants I18n dependencies are moved to class methods
      I18n.t('question')
    end

    def meta_data
      Helpdesk::DEFAULT_TICKET_PROPERTIES[:feedback_widget_ticket][:meta]
    end

    def created_at
      account.created_at - 1.hour
    end
end