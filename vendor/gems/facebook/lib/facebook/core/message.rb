module Facebook
  module Core
    class Message

      include Social::Util
      include Facebook::Exception::Handler
      
      attr_accessor :page_id, :realtime_message, :fan_page, :dynamo_helper
      
      def initialize(page_id, message)
        @page_id          = page_id
        @realtime_message = message
        @dynamo_helper    = Social::Dynamo::Facebook.new
      end

      def account_and_page_validity
        select_fb_shard_and_account(page_id) do |account|    
          if account.present? and account.active?
            @fan_page = account.facebook_pages.find_by_page_id(page_id)
            {
              :valid_account => true, :valid_page => @fan_page.valid_page?, 
              :realtime_messaging => @fan_page.realtime_messaging, :import_dms => @fan_page.import_dms
            }
          else
            {
              :valid_account => false, :valid_page => false, 
              :realtime_messaging => false, :import_dms => false
            }
          end
        end
      end

      def process(raw_obj)
        select_shard_and_account(@fan_page.account_id) do |account|
          sandbox(raw_obj) do
            rt_message = KoalaWrapper::RealTimeMessage.new(fan_page, realtime_message)
            rt_message.process()
          end
        end
      end

    end
  end
end