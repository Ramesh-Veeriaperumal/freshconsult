require File.expand_path("#{File.dirname(__FILE__)}/../../spec_helper")

describe Social::FacebookPosts do
  
  before(:all) do
    @account = create_test_account
    # Social::FacebookPage.any_instance.stubs(:after_commit_on_create => true)
    # Social::FacebookPage.any_instance.stubs(:after_commit_on_update => true)
    FBClient.any_instance.stubs(:subscribe_for_page).returns(true)
    Social::FacebookPosts.any_instance.stubs(:fetch).returns({})
    fb_page = Factory.build(:facebook_pages)
    fb_page.account_id = @account.id
    fb_page.save(false)
  end
  after(:all) do
    FBClient.any_instance.stubs(:subscribe_for_page).returns(true)
    Social::FacebookPosts.any_instance.stubs(:fetch).returns({})
    Social::FacebookPage.destroy_all
    Helpdesk::Ticket.destroy_all
  end

  describe "fetch the delta" do
  	context "tickets " do
  		
  	end

  	context "comments " do
  	end

  	context "rate limit" do
  	end
  end
end
