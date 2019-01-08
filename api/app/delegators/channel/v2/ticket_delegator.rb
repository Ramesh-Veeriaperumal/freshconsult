module Channel::V2
  class TicketDelegator < ::TicketDelegator

    validate :fb_page_presence, on: :create

    def ticket_fields
      []
    end

    def fb_page_presence
      if facebook_ticket?
        errors[:facebook_page_id] << :"facebook page not added" unless self.fb_post.facebook_page
      end
    end

    def facebook_ticket?
      ::TicketConstants::SOURCE_KEYS_BY_TOKEN[:facebook] == self.source
    end
  end
end