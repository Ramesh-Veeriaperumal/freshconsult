class Fixtures::DefaultFeedbackWidgetTicket < Fixtures::DefaultTicket

  private

    def priority
      TicketConstants::PRIORITY_KEYS_BY_TOKEN[:low]
    end

    def source
      TicketConstants::SOURCE_KEYS_BY_TOKEN[:feedback_widget]
    end

    def type
      #REVISIT . Need to change this after ticket constants I18n dependencies are moved to class methods
      I18n.t('f_request')
    end

    def meta_data
      Helpdesk::DEFAULT_TICKET_PROPERTIES[:feedback_widget_ticket][:meta]
    end
end