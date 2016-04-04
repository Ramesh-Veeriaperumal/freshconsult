require 'spec_helper'

describe Admin::Social::TwitterHandlesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false
  
  before(:each) do
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      GnipRule::Client.any_instance.stubs(:add).returns(add_response)
      GnipRule::Client.any_instance.stubs(:delete).returns(delete_response)
    end
    login_admin
  end
  
  describe "GET #authdone" do
    
    it "should redirect to new handle if it doesn't exists and create a default stream/dm stream and ticket rule for dm stream" do 
      Resque.inline = true
      handle = FactoryGirl.build(:twitter_handle, :account_id => @account.id, :twitter_user_id => "#{get_social_id}")
      Resque.inline = false
      TwitterWrapper.any_instance.stubs(:auth).returns(handle)
      
      get :authdone
      
      response.should redirect_to "/admin/social/twitter_streams/#{handle.default_stream.id}/edit"
      
      handle.twitter_streams.count.should eql(2)
      default_stream = handle.default_stream
      dm_stream = handle.dm_stream
      default_stream.should_not be_nil
      dm_stream.should_not be_nil
    end
    
    
    it "should redirect to existing stream if stream already exists" do    
      Resque.inline = true
      handle = FactoryGirl.build(:twitter_handle, :account_id => @account.id, :twitter_user_id => "#{get_social_id}")
      Resque.inline = false
      TwitterWrapper.any_instance.stubs(:auth).returns(handle)
      
      #Create a new handle  
      get :authdone
      response.should redirect_to "/admin/social/twitter_streams/#{handle.default_stream.id}/edit"
      count = @account.twitter_handles.count  
      streams_before = handle.twitter_streams
          
      #Add same handle again
      get :authdone  
      @account.twitter_handles.count.should be_eql(count)    
      response.should redirect_to "/admin/social/twitter_streams/#{handle.default_stream.id}/edit"
      streams_after = handle.twitter_streams
      
      streams_before.count.should eql(streams_after.count)
    end
    
    it "should redirect to admin/social/streams if exception arise" do
      TwitterWrapper.any_instance.stubs(:auth).raises(Errno::ECONNRESET)     
      get :authdone
      response.should redirect_to "/admin/social/streams"
    end
    
  end
  
  describe "DELETE #destroy" do    
    it "should delete and redirect" do
      Resque.inline = true
      twt_handler = create_test_twitter_handle(@account)  
      delete :destroy, :id => twt_handler.id
      handle = @account.twitter_handles.find_by_id(twt_handler.id)
      handle.present?.should be_falsey
      response.should redirect_to '/admin/social/streams'
      Resque.inline = false   
    end
  end
  
  after(:all) do
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      GnipRule::Client.any_instance.stubs(:delete).returns(delete_response) 
    end
    Social::TwitterHandle.destroy_all
    Resque.inline = false
  end
  
end
