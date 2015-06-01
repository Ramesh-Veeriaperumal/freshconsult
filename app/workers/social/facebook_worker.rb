module Social
  class FacebookWorker < BaseWorker
    
    
    include Facebook::KoalaWrapper::ExceptionHandler
    
    sidekiq_options :queue => :facebook, :retry => 0, :backtrace => true, :failures => :exhausted

    ERROR_MESSAGES = {
      :access_token_error => "access token", 
      :permission_error => "manage_pages",
      :mailbox_error => "read_page_mailboxes" 
    }

    def perform(msg = nil)
      Koala.config.api_version = "v2.2" 
      account = Account.current
      if msg and msg['fb_page_id']
        fan_page = account.facebook_pages.find(msg['fb_page_id'])
        fetch_from_fb fan_page
      else
        fb_pages = account.facebook_pages.valid_pages
        fb_pages.each do |fan_page|
         fetch_from_fb fan_page
        end
      end
      ensure
        Account.reset_current_account
    end

    private
      def fetch_from_fb fan_page
        fetch_fb_posts(fan_page) unless fan_page.realtime_subscription #This will get removed
        fetch_fb_messages(fan_page) if fan_page.import_dms
      end

      def fetch_fb_messages fan_page
        sandbox(true) do
          @fan_page = fan_page
          fb_worker = Facebook::Core::Message.new(@fan_page)
          fb_worker.fetch_messages
        end
      end

      def fetch_fb_posts fan_page
        sandbox(true) do      
          @fan_page = fan_page
          @fan_page.update_attributes(:realtime_subscription => "true") if @fan_page.account.features?(:facebook_realtime)
                
          if @fan_page.company_or_visitor?
            fb_posts = Facebook::Fql::Posts.new(@fan_page)
            Koala.config.api_version == "v2.2" ? fb_posts.fetch_latest_posts : fb_posts.fetch
          end      
        end
      end
  end
end
