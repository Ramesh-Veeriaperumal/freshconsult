class Social::FacebookCommentsWorker
	extend Resque::AroundPerform
  include Facebook::KoalaWrapper::ExceptionHandler
	@queue = "facebook_comments_worker"


	  def self.perform(args)
      account = Account.current
      facebook_pages = account.facebook_pages.find(:all, :conditions => ["enable_page = 1 and reauth_required = 0"])
      return if facebook_pages.empty?
      facebook_pages.each do |fan_page|
        fetch_fb_comments fan_page
      end
  	end

  	def self.fetch_fb_comments fan_page
  		sandbox(true) do
        @fan_page = fan_page
    		fb_posts = Social::FacebookPosts.new(fan_page)
    		fb_posts.get_comment_updates((Time.zone.now.ago 1.hours).to_i)
    	end
	  end

end
