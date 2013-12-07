require File.expand_path("#{File.dirname(__FILE__)}/../../spec_helper")

describe Facebook::KoalaWrapper::Comment do

  before(:all) do
    @account = create_test_account
    Social::FacebookPage.any_instance.stubs(:after_commit_on_create => true)
    Social::FacebookPage.any_instance.stubs(:after_commit_on_update => true)
    FBClient.any_instance.stubs(:subscribe_for_page).returns(true)
    # Social::FacebookPosts.any_instance.stubs(:fetch).returns({})
    fb_page = Factory.build(:facebook_pages)
    fb_page.account_id = @account.id
    fb_page.save(false)
  end

  after(:all) do
    FBClient.any_instance.stubs(:subscribe_for_page).returns(true)
    # Social::FacebookPosts.any_instance.stubs(:fetch).returns({})
    Social::FacebookPage.destroy_all
  end

  after(:each) do
    Helpdesk::Ticket.destroy_all
  end


  describe "pass a comment feed" do
    it "should create a koala comment object" do
      koala_wrapper = Facebook::KoalaWrapper::Comment.new(Social::FacebookPage.first)
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns({"user_likes"=>false, "can_remove"=>true, "id"=>"603466913018257_7126753", "like_count"=>0, "created_time"=>"2013-07-18T11:26:39+0000", "message"=>"commenting for new post", "from"=>{"name"=>"Causeeeeeeeadded", "id"=>"532218423476440", "category"=>"Cause"}})
      koala_wrapper.fetch_comment("603466913018257_7126753")
      koala_wrapper.message.should eql "commenting for new post"
      koala_wrapper.created_at.to_s.should eql "2013-07-18 16:56:39 +0530"
      koala_wrapper.comment_id.should eql "603466913018257_7126753"
    end
  end

end
