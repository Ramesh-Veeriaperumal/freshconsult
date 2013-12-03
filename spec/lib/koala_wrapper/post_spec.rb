require File.expand_path("#{File.dirname(__FILE__)}/../../spec_helper")

describe Facebook::KoalaWrapper::Post do

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


  describe "pass a post" do
    it "should create a koala post object" do
      koala_wrapper = Facebook::KoalaWrapper::Post.new(Social::FacebookPage.first)
      Koala::Facebook::GraphAndRestAPI.any_instance.stubs(:get_object).returns({"to"=>{"data"=>[{"name"=>"Causeeeeeeeadded", "category"=>"Cause", "id"=>"532218423476440"}]}, "message"=>"this is a new post", "id"=>"532218423476440_603466913018257", "comments"=>{"data"=>[{"can_remove"=>true, "message"=>"commenting for new post", "id"=>"603466913018257_7126753", "created_time"=>"2013-07-18T11:26:39+0000", "from"=>{"name"=>"Causeeeeeeeadded", "category"=>"Cause", "id"=>"532218423476440"}, "user_likes"=>false, "like_count"=>0}], "paging"=>{"cursors"=>{"after"=>"MQ==", "before"=>"MQ=="}}}, "updated_time"=>"2013-07-18T11:26:39+0000", "type"=>"status", "created_time"=>"2013-07-18T11:17:52+0000", "privacy"=>{"value"=>""}, "from"=>{"name"=>"Rikacho Paul", "id"=>"100005115430108"}, "actions"=>[{"name"=>"Comment", "link"=>"https://www.facebook.com/532218423476440/posts/603466913018257"}, {"name"=>"Like", "link"=>"https://www.facebook.com/532218423476440/posts/603466913018257"}]})
      koala_wrapper.fetch_post("532218423476440_603466913018257")
      koala_wrapper.description.should eql "this is a new post"
      koala_wrapper.description_html.should eql "this is a new post" 
      koala_wrapper.subject.should eql "this is a new post"
      koala_wrapper.created_at.to_s.should eql "2013-07-18 16:47:52 +0530"
    end
  end

end
