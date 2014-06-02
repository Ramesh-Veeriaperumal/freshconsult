module Social
  class FacebookWorker < BaseWorker
    
    
    include Facebook::KoalaWrapper::ExceptionHandler
    sidekiq_options :queue => :facebook, :retry => 0, :backtrace => true, :failures => :exhausted

    ERROR_MESSAGES = {
      :access_token_error => "access token", 
      :permission_error => "manage_pages",
      :mailbox_error => "read_page_mailboxes" 
    }

    def perform(msg)
      account = Account.current
      facebook_pages = execute_on_db do 
        account.facebook_pages.find(:all, :conditions => ["enable_page = 1"])
      end
      facebook_pages.each do |fan_page|
          #This will get removed
          fetch_fb_posts(fan_page) unless fan_page.realtime_subscription
          if fan_page.import_dms && !(fan_page.last_error &&
                                  fan_page.last_error.include?(ERROR_MESSAGES[:mailbox_error]))
              fetch_fb_messages fan_page
          end
       end
    ensure
      Account.reset_current_account
    end

    private
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
          fb_posts = Social::FacebookPosts.new(@fan_page)
          fb_posts.fetch
        end
      end
  end
end