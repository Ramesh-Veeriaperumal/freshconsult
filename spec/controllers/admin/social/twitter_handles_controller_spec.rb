require 'spec_helper'

describe Admin::Social::TwitterHandlesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false
  
  before(:all) do
    @account = create_test_account
    @agent_role = @account.roles.find_by_name("Agent")
    @user = add_test_agent(@account)
  end
  
  before(:each) do
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      Gnip::RuleClient.any_instance.stubs(:add).returns(add_response)
      Gnip::RuleClient.any_instance.stubs(:delete).returns(delete_response)
    end
    @request.host = @account.full_domain
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                      (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    log_in(@user)
  end
  
  describe "GET #authdone" do
    
    it "should redirect to new handle if it doesn't exists and create a default stream/dm stream and ticket rule for dm stream" do    
      Resque.inline = true
      handle = create_test_twitter_handle(@account)
      Resque.inline = false
      handle.update_attributes(:capture_dm_as_ticket => true)
      TwitterWrapper.any_instance.stubs(:auth).returns(handle)
      
      get :authdone
      response.should redirect_to "admin/social/twitter_streams/#{@handle.default_stream.id}/edit"
      
      handle.twitter_streams.count.should eql(2)
      default_stream = @handle.default_stream
      dm_stream = @handle.dm_stream
      default_stream.should_not be_nil
      dm_stream.should_not be_nil
    end
    
    
    it "should redirect to existing stream if stream already exists" do  
      Resque.inline = true
      handle = create_test_twitter_handle(@account)
      Resque.inline = false
      handle.update_attributes(:capture_dm_as_ticket => true)
      TwitterWrapper.any_instance.stubs(:auth).returns(handle)
      
      #Create a new handle  
      get :authdone
      response.should redirect_to "admin/social/twitter_streams/#{@handle.default_stream.id}/edit"
      count = @account.twitter_handles.count  
      streams_before = handle.twitter_streams
          
      #Add same handle again
      get :authdone  
      @account.twitter_handles.count.should be_eql(count)    
      response.should redirect_to "admin/social/twitter_streams/#{@handle.default_stream.id}/edit"
      streams_after = handle.twitter_streams
      
      streams_before.count.should eql(streams_after.count)
    end
    
    it "should redirect to admin/social/streams if exception arise" do
      TwitterWrapper.any_instance.stubs(:auth).raises(Errno::ECONNRESET)     
      get :authdone
      response.should redirect_to "admin/social/streams"
    end
    
  end
  
  describe "DELETE #destroy" do    
    it "should delete and redirect" do
      Resque.inline = true
      twt_handler = create_test_twitter_handle(@account)  
      delete :destroy, :id => twt_handler.id
      handle = @account.twitter_handles.find_by_id(twt_handler.id)
      handle.present?.should be_false
      response.should redirect_to 'admin/social/streams'
      Resque.inline = false   
    end
  end
  
end
