module OmniChannelsTestHelper
  def channel_json(expected_output)
    {
      facebook: expected_output[:facebook] || false,
      twitter: expected_output[:twitter] || false,
      freshcaller: expected_output[:freshcaller] || false,
      freshchat: expected_output[:freshchat] || false
    }
  end

  def channel_availability
    fb_page = FactoryGirl.build(:facebook_pages, account_id: @account.id)
    fb_page.sneaky_save
    twitter = @account.twitter_handles.new
    twitter.twitter_user_id = 1
    twitter.screen_name = 'ocr'
    twitter.save
    freshchat = @account.build_freshchat_account
    freshchat.app_id = 'test'
    freshchat.enabled = true
    freshchat.save
    @account.build_freshcaller_account.save
  end

  def no_channels
    @account.facebook_pages.destroy_all
    @account.twitter_handles.delete_all
    @account.freshchat_account.enabled = false
    @account.freshchat_account.destroy
    @account.freshcaller_account.destroy
  end

  def org_admin_users_response
    {
      users: [{
        id: Faker::Number.number(5),
        email: Faker::Internet.email
      }]
    }
  end
end
