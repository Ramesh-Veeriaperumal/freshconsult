module Social
  class FacebookWorker < BaseWorker
    include Facebook::RedisMethods
    include Facebook::Exception::Handler
    include SidekiqSemaphore
    include Redis::Keys::Semaphore

    sidekiq_options queue: :facebook, retry: 0,  failures: :exhausted

    ERROR_MESSAGES = {
      access_token_error: 'access token',
      permission_error: 'manage_pages',
      mailbox_error: 'read_page_mailboxes'
    }.freeze

    def perform(msg = nil)
      return if app_rate_limit_reached?
      Koala.config.api_version = Facebook::Constants::GRAPH_API_VERSION
      account = Account.current
      page_id = msg && msg['fb_page_id']
      key = format(FACEBOOK_SEMAPHORE, account_id: account.id, page_id: page_id || 0)
      semaphore(key) do
        if page_id
          fan_page = account.facebook_pages.find_by_id(msg['fb_page_id'])
          fetch_from_fb fan_page if fan_page
        else
          fb_pages = account.facebook_pages.valid_pages
          fb_pages.each do |page|
            fetch_from_fb(page)
          end
        end
      end
    ensure
      Account.reset_current_account
    end

    private

      def fetch_from_fb(fan_page)
        if page_rate_limit_reached?(fan_page.account_id, fan_page.page_id)
          Rails.logger.debug "#{fan_page.page_id} #{fan_page.account_id} Return on page rate limit reached"
          return
        end
        fetch_fb_posts(fan_page) if fan_page.message_since.nil?
        fetch_fb_messages(fan_page) if fan_page.import_dms && !fan_page.realtime_messaging
      end

      def fetch_fb_messages(fan_page)
        sandbox do
          @fan_page = fan_page
          fb_worker = Facebook::KoalaWrapper::DirectMessage.new(@fan_page)
          fb_worker.fetch_messages
        end
      end

      def fetch_fb_posts(fan_page)
        sandbox do
          @fan_page = fan_page
          if @fan_page.company_or_visitor?
            fb_posts = Facebook::Graph::Posts.new(@fan_page)
            fb_posts.fetch_latest_posts
          end
        end
      end
  end
end
