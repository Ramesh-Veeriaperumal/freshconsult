namespace :facebook do
  desc 'Check for New facebook feeds..'
  task :fetch => :environment do    
    puts "Facebook task initialized at #{Time.zone.now}"
    Account.active_accounts.each do |account|
      account.make_current
      facebook_pages = account.facebook_pages.find(:all, :conditions => ["enable_page = 1"])    
      facebook_pages.each do |fan_page| 
        fb_sandbox do ### starts ####
           @fan_page = fan_page
           fb_posts = Social::FacebookPosts.new(fan_page)
           fb_posts.fetch
           
           if fan_page.import_dms
              fb_messages = Social::FacebookMessage.new(fan_page)
              fb_messages.fetch
           end
         
         end ### ends ####
     end
   end
    Account.reset_current_account
    puts "Facebook task finished at #{Time.zone.now}"
  end
  
  ##Need to consider the 
 
  
  def fb_sandbox
      begin
        yield
      rescue Koala::Facebook::APIError => e
        @fan_page.update_attributes({ :reauth_required => true, :last_error => e.to_s})
        puts e.to_s
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened in facebook!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
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