module Social
  class FbCommentsWorker < Social::FacebookWorker
    
    
    sidekiq_options :queue => :facebook_comments, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(msg)
      account = Account.current
      @fan_page = execute_on_db { account.facebook_pages.find(msg['fb_page_id']) }
      fetch_fb_comments @fan_page
    ensure
      Account.reset_current_account
    end

    private
      def fetch_fb_comments fan_page
        sandbox(true) do
            fb_posts = Facebook::Fql::Posts.new(fan_page)
            fb_posts.get_comment_updates((Time.zone.now.ago 2.hours).to_i)
        end
      end
  end
end
