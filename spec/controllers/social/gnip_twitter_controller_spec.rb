require 'spec_helper'
include Social::Twitter::Constants

describe Social::GnipTwitterController do
  integrate_views
  self.use_transactional_fixtures = false
  
  before(:all) do
    @account = create_test_account
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                        (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
  end
  
  describe "POST #reconnect" do
    
    it "should update reconnect timestamp in redis" do
      
      now = Time.now
      time = (now + 5.minutes).iso8601
            
      epoch = now.to_i / TIME[:reconnect_timeout]
      
      data    = "#{time}#{epoch}"
      digest  = OpenSSL::Digest::Digest.new('sha512')
      hash    = OpenSSL::HMAC.hexdigest(digest, GnipConfig::GNIP_SECRET_KEY, data)
      
      post :reconnect, {:reconnect_time => time, :hash => hash}
            
      json = JSON.parse(response.body)
      
      json['success'].should be_true
    end
    
    it "should render success as false if reconnect_time or hash parameter is not present" do
          
      post :reconnect, {:reconnect_time => (Time.now + 5.minutes).iso8601 }
          
      json = JSON.parse(response.body)
          
      json['success'].should be_false
    end
    
    
    
    it "should not update in redis when request comes from malicious user" do
      
      post :reconnect, {:reconnect_time => Time.now.iso8601, :hash => Faker::Lorem.characters(100) }
            
      json = JSON.parse(response.body)
      
      json['success'].should be_false
    end
    
  end
end