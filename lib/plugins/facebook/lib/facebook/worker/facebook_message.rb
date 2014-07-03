#This Rescue is used For sinking the message threads.Currently this is run every 4 minutes
class Facebook::Worker::FacebookMessage
	extend Resque::AroundPerform
  include Facebook::KoalaWrapper::ExceptionHandler
  @queue = 'FacebookWorker'

  ERROR_MESSAGES = {:access_token_error => "access token", :permission_error => "manage_pages", 
                    :mailbox_error => "read_page_mailboxes" }
  
  class PremiumFacebookWorker
    extend Resque::AroundPerform
    @queue = 'premium_facebook_worker'

    def self.perform(args)
     Facebook::Worker::FacebookMessage.run
    end
  end

  def self.perform(args)
    run
  end

  def self.run
    account = Account.current
    return if account.facebook_pages.empty?
    facebook_pages = account.facebook_pages.find(:all, :conditions => ["enable_page = 1"])
    facebook_pages.each do |fan_page|
        #This will get removed
        fetch_fb_posts(fan_page) unless fan_page.realtime_subscription
        if fan_page.import_dms && !(fan_page.last_error &&
                                fan_page.last_error.include?(ERROR_MESSAGES[:mailbox_error]))
            fetch_fb_messages fan_page
        end
     end
  end

  def self.fetch_fb_messages fan_page
    sandbox(true) do
      @fan_page = fan_page
      fb_worker = Facebook::Core::Message.new(@fan_page)
      fb_worker.fetch_messages
    end
  end

  def self.fetch_fb_posts fan_page
    sandbox(true) do
      @fan_page = fan_page
      @fan_page.update_attributes(:realtime_subscription => "true") if @fan_page.account.features?(:facebook_realtime)
      fb_posts = Social::FacebookPosts.new(@fan_page)
      fb_posts.fetch
    end
  end
end
