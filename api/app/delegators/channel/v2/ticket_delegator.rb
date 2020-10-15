module Channel::V2
  class TicketDelegator < ::TicketDelegator

    validate :fb_page_presence, on: :create
    validate :twitter_handle_presence, on: :create

    def ticket_fields
      []
    end

    def fb_page_presence
      if facebook_ticket?
        errors[:facebook_page_id] << :"facebook page not added" unless self.fb_post.facebook_page
      end
    end

    def facebook_ticket?
      Helpdesk::Source::FACEBOOK == self.source
    end

    def twitter_handle_presence
      if twitter_ticket?
        errors[:twitter_handle_id] << :invalid_twitter_handle unless self.tweet.twitter_handle
      end
    end

    def twitter_ticket?
      Helpdesk::Source::TWITTER == self.source
    end
  end
end