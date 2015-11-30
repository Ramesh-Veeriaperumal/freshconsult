require 'spec_helper'


describe Social::UploadAvatar do
  self.use_transactional_fixtures = false
  
  before(:all) do
    @handle = create_test_twitter_handle(@account)
    user_name = Faker::Name.name
    twitter_user_id = user_name.split.first
    @twitter_user = FactoryGirl.build(:user, :account => @account,
                                      :name => user_name, 
                                      :twitter_id => twitter_user_id,
                                      :time_zone => "Chennai", 
                                      :delta => 1, 
                                      :language => "en") 
   @twitter_user.save
   @img_url = "https://abs.twimg.com/sticky/default_profile_images/default_profile_5_bigger.png"
  end
  
  context "For twitter handles" do
    it "must build an avatar" do
      sender1 = Time.now.utc.to_i
      handle_data = sample_twitter_user(sender1)
      Twitter::REST::Client.any_instance.stubs(:user).returns(handle_data)
      Twitter::User.any_instance.stubs(:profile_image_url).returns(@img_url)
      Social::UploadAvatar.perform_async({:account_id => @account.id, :twitter_handle_id => @handle.id})
      @handle.avatar.should_not be_nil
    end
  end
  
  context "For twitter user" do
    it "must build an avatar" do
      args = {
        :account_id       => @account.id,
        :twitter_user_id  => @twitter_user.id,
        :prof_img_url     => @img_url
      }
      Social::UploadAvatar.perform_async(args)
      @twitter_user.avatar.should_not be_nil
    end
  end
  
  after(:all) do
    @handle.destroy
    @twitter_user.destroy
  end
end
