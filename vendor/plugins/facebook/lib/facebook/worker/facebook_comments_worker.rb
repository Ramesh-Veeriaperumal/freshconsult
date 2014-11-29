class Facebook::Worker::FacebookCommentsWorker
  extend Resque::AroundPerform
  include Facebook::KoalaWrapper::ExceptionHandler
  @queue = "facebook_comments_worker"


    def self.perform(args)
      account = Account.current
      facebook_pages = account.facebook_pages.valid_pages
      return if facebook_pages.empty?
      facebook_pages.each do |fan_page|
        fetch_fb_comments fan_page
      end
    end

    def self.fetch_fb_comments fan_page
      sandbox(true) do
        @fan_page = fan_page
        fb_posts = Facebook::Fql::Posts.new(fan_page)
        fb_posts.get_comment_updates((Time.zone.now.ago 30.minutes).to_i)
      end
    end

end
