class TwitterWrapper
  
  require 'twitter'  
 
  attr_reader :tokens

  def initialize(twitter_handle , options = {} )
    @product = options[:product] || twitter_handle.product
    @account = options[:current_account]  || twitter_handle.product.account
    @config = File.join(Rails.root, 'config', 'twitter.yml')
    @tokens = YAML::load_file @config
    @callback_url = @tokens['callback_url'][Rails.env]
    @callback_url = "#{@callback_url}?product_id=#{@product.id}"
    @auth = Twitter::OAuth.new @tokens['consumer_token'], @tokens['consumer_secret']
    @twitter_handle = twitter_handle
  end

  def request_tokens   
    rtoken = @auth.request_token  (:oauth_callback => @callback_url)       
  end

  def authorize_url
    @auth.request_token(:oauth_callback => @callback_url).authorize_url
  end

##Need to consider re-authorize where we dont need to add the same twitter handle again
  def auth(rtoken, rsecret, verifier)    
    @auth.authorize_from_request(rtoken, rsecret, verifier)        
    @twitter_handle.access_token, @twitter_handle.access_secret = @auth.access_token.token, @auth.access_token.secret
    set_twitter_user   
    @twitter_handle.save    
  end
  
  def set_twitter_user
    @auth.authorize_from_access(@twitter_handle.access_token, @twitter_handle.access_secret)
    twitter = Twitter::Base.new @auth
    cred = twitter.verify_credentials
    twitter_id = cred.id_str
    screen_name = cred.screen_name        
    @user = @account.all_users.find_by_twitter_id(screen_name)   
    if @user.blank?
       @user = @account.users.new          
       @user.signup!({:user => {:deleted =>true, :twitter_id =>screen_name , :name => screen_name , :user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer]}})
    end            
    @twitter_handle.user = @user
    @twitter_handle.twitter_user_id = twitter_id.to_i()
    @twitter_handle
  end

  def get_twitter    
    @auth.authorize_from_access(@twitter_handle.access_token, @twitter_handle.access_secret)
    twitter = Twitter::Base.new @auth
    twitter.home_timeline(:count => 1)
    twitter
  end
  
  
end