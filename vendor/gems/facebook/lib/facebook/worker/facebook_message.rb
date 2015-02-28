#This resque is used for syncing the message threads. Currently this is run every 4 minutes
class Facebook::Worker::FacebookMessage
  extend Resque::AroundPerform
  include Facebook::KoalaWrapper::ExceptionHandler
  @queue = 'FacebookWorker'
  
  class PremiumFacebookWorker
    extend Resque::AroundPerform
    @queue = 'premium_facebook_worker'

    def self.perform(args)
     Facebook::Worker::FacebookMessage.run(args)
    end
  end

  def self.perform(args)
    run
  end

  def self.run
    Koala.config.api_version = nil #reset koala version so that we hit v1 api
    
    account = Account.current
    facebook_pages = account.facebook_pages.valid_pages
    return if facebook_pages.empty?
    facebook_pages.each do |fan_page|        
      fetch_fb_posts(fan_page) unless fan_page.realtime_subscription #This will get removed
      fetch_fb_messages(fan_page) if fan_page.import_dms
    end
  end

  def self.fetch_from_fb fan_page
    fetch_fb_posts(fan_page) unless fan_page.realtime_subscription #This will get removed
    fetch_fb_messages(fan_page) if fan_page.import_dms
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
      fb_posts = Facebook::Fql::Posts.new(@fan_page)
      fb_posts.fetch if @fan_page.company_or_visitor?
    end
  end
end
