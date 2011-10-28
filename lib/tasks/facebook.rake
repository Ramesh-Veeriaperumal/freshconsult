namespace :facebook do
  desc 'Check for New facebook feeds..'
  task :fetch => :environment do    
    puts "facebook..fetch is called"
    Account.active_accounts.each do |account|
      facebook_pages = account.facebook_pages.find(:all, :conditions => ["enable_page = 1"])    
      facebook_pages.each do |fan_page| 
        puts "facebook---fetch has been called for page :: #{fan_page.page_name}"
        sandbox do ### starts ####
 
           fb_posts = Social::FacebookPosts.new(fan_page)
           fb_posts.fetch
         
         end ### ends ####
      end
    end
  end
  
  ##Need to consider the 
 
  
  def sandbox
      begin
        yield
      rescue Errno::ECONNRESET => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Timeout::Error => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue EOFError => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Errno::ETIMEDOUT => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue OpenSSL::SSL::SSLError => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue SystemStackError => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Exception => e
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue 
        puts e.to_s
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
      end
    end
  
end