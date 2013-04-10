class Social::FacebookCommentsWorker
	extend Resque::AroundPerform
	@queue = "FacebookCommentsWorker"


	  def self.perform(args)
    	account = Account.current
    	@fan_page = account.facebook_pages.find(args[:fb_page_id])
      fetch_fb_comments @fan_page
  	end

  	def self.fetch_fb_comments fan_page
  		sandbox do
      		fb_posts = Social::FacebookPosts.new(fan_page)
      		fb_posts.get_comment_updates((Time.zone.now.ago 2.hours).to_i)
    	end
	  end

    def self.sandbox
    begin
      yield
    rescue Koala::Facebook::APIError => e
      if e.fb_error_type == 4 #error code 4 is for api limit reached
        @fan_page.attributes = {:last_error => e.to_s}
        @fan_page.save
        puts "API Limit reached - #{e.to_s} :: account_id => #{@fan_page.account_id} :: id => #{@fan_page.id} "
        NewRelic::Agent.notice_error(e, {:custom_params => {:error_type => e.fb_error_type, :error_msg => e.to_s}})
      else
        @fan_page.attributes = {:enable_page => false} if e.to_s.include?(Social::FacebookWorker::ERROR_MESSAGES[:access_token_error]) ||
                                                          e.to_s.include?(Social::FacebookWorker::ERROR_MESSAGES[:permission_error])
        @fan_page.attributes = { :reauth_required => true, :last_error => e.to_s }  \
                        if Social::FacebookWorker::ERROR_MESSAGES.any? {|k,v| e.to_s.include?(v)} 
        @fan_page.save
        NewRelic::Agent.notice_error(e, {:custom_params => {:error_type => e.fb_error_type, :error_msg => e.to_s, 
                                            :account_id => @fan_page.account_id, :id => @fan_page.id }})
        puts "APIError while processing facebook - #{e.to_s}  :: account_id => #{@fan_page.account_id} :: id => #{@fan_page.id} "
      end
    rescue Exception => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        puts "Error while processing facebook - #{e.to_s}"
    end
  end

end