class TwitterWrapper
  
  require 'twitter'  
 
  attr_reader :tokens

  def initialize(twitter_handle , options = {} )
    @product = options[:product] || twitter_handle.product
    @account = options[:current_account]  || twitter_handle.account
    @config = File.join(Rails.root, 'config', 'twitter.yml')
    @tokens = YAML::load_file @config
    @callback_url = "#{options[:callback_url]}"
    @callback_url = "#{@callback_url}?product_id=#{@product.id}"
    @consumer ||= OAuth::Consumer.new @tokens['consumer_token'][Rails.env], @tokens['consumer_secret'][Rails.env], {:site => "http://api.twitter.com"}
    @twitter_handle = twitter_handle
    Twitter.configure do |config|
      config.consumer_key = @tokens['consumer_token'][Rails.env]
      config.consumer_secret = @tokens['consumer_secret'][Rails.env]
    end

  end

  def request_tokens   
    rtoken = @consumer.get_request_token(:oauth_callback => @callback_url)       
  end

##Need to consider re-authorize where we dont need to add the same twitter handle again
  def auth(rtoken,rsecret, verifier)    
    request_token = OAuth::RequestToken.new(@consumer,rtoken,rsecret)
    access_token = request_token.get_access_token(:oauth_verifier => verifier)        
    @twitter_handle.access_token, @twitter_handle.access_secret = access_token.token, access_token.secret
    @twitter_handle.account_id = @account.id
    set_twitter_user   
  end
  
  def set_twitter_user
    twitter = Twitter::Client.new(:oauth_token => @twitter_handle.access_token,
                                  :oauth_token_secret => @twitter_handle.access_secret)
    
    cred = twitter.verify_credentials
    @twitter_handle.screen_name = cred.screen_name   
    @twitter_handle.twitter_user_id = cred.id.to_i()
    @twitter_handle
  end

  def get_twitter    
    twitter = Twitter::Client.new(:oauth_token => @twitter_handle.access_token,
                                  :oauth_token_secret => @twitter_handle.access_secret)
    #twitter.home_timeline.first
    twitter
  end
  
  
end