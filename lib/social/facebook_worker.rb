class Social::FacebookWorker
	extend Resque::Plugins::Retry
  @queue = 'FacebookWorker'

  @retry_limit = 3
  @retry_delay = 60*2

  ERROR_MESSAGES = {:access_token_error => "access token", :permission_error => "manage_pages"}
  
  def self.perform(account_id)
    account = Account.find(account_id)
    account.make_current
    facebook_pages = account.facebook_pages.find(:all, :conditions => ["enable_page = 1"])    
    facebook_pages.each do |fan_page|   
        @fan_page =  fan_page
        fetch_fb_posts fan_page     
        if fan_page.import_dms
            fetch_fb_messages fan_page
        end         
     end
     Account.reset_current_account
  end

  def self.fetch_fb_messages fan_page
    sandbox do
      fb_posts = Social::FacebookMessage.new(fan_page)
      fb_posts.fetch
    end
  end

  def self.fetch_fb_posts fan_page
    sandbox do
      fb_posts = Social::FacebookPosts.new(fan_page)
      fb_posts.fetch
    end
  end

  def self.sandbox
    begin
      yield
    rescue Koala::Facebook::APIError => e      
        @fan_page.attributes = {:enable_page => false} if e.to_s.include?(ERROR_MESSAGES[:access_token_error]) ||
                                                          e.to_s.include?(ERROR_MESSAGES[:permission_error])
        @fan_page.attributes = { :reauth_required => true, :last_error => e.to_s }
        @fan_page.save 
        NewRelic::Agent.notice_error(e)
        puts "Error while processing facebook"
        puts e.to_s
    rescue Exception => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        puts "Error while processing facebook"
        puts e.to_s
    end
  end
end