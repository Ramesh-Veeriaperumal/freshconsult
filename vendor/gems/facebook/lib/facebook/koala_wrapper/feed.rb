module Facebook
  module KoalaWrapper
    class Feed
      
      include Social::Util
      include Facebook::Util
      include Facebook::Constants
      include Facebook::KoalaWrapper::Helper

      attr_accessor :feed, :feed_id, :requester, :created_at, :description, :subject, 
                    :comments
      
      def initialize(fan_page)
        @account   = Account.current
        @fan_page  = fan_page
        @rest      = Koala::Facebook::API.new(fan_page.page_token)
        @comments  = []
      end
      
      def parse
        @feed            =  @feed.deep_symbolize_keys
        @feed_id         =  @feed[:id]
        @requester       =  @feed[:from].symbolize_keys! if @feed[:from]
        @created_at      =  Time.zone.parse(@feed[:created_time])
        @feed[:message]  =  @feed[:message].to_s.tokenize_emoji
        @description     =  @feed[:message].to_s
        @subject         =  truncate_subject(@description, 100)
        @comments        =  @feed[:comments][:data] if @feed[:comments] && @feed[:comments][:data]
      end
      
      def by_visitor?
        requester_fb_id != @fan_page.page_id.to_s
      end
      
      def by_company?
        !by_visitor?
      end
     
      def requester_fb_id
        @requester.is_a?(Hash) ? @requester[:id] : @requester
      end
      
      
    end
  end
end
