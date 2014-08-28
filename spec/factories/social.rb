if Rails.env.test?
  FactoryGirl.define do
    factory :facebook_pages, :class => Social::FacebookPage do
      sequence(:page_id) { |n| n }
      profile_id 123456
      page_token "123456"
      access_token "123456"
      enable_page true
      fetch_since 0
      import_visitor_posts false
      import_company_posts false
      realtime_subscription true
    end

    factory :facebook_mapping, :class => Social::FacebookPageMapping do
      facebook_page_id "532218423476440"
    end

    factory :twitter_handle, :class => Social::TwitterHandle do
      screen_name "TestingGnip"
      capture_dm_as_ticket true
      capture_mention_as_ticket false
      search_keys []
      twitter_user_id { (Time.now.utc.to_f*1000000).to_i }
    end
    
    factory :twitter_stream, :class => Social::TwitterStream do
      name "Custom Social Stream"
      type "Social::TwitterStream"
      includes ["Freshdesk"]
      excludes []
      data HashWithIndifferentAccess.new({:kind => "Custom" })
      filter HashWithIndifferentAccess.new({:exclude_twitter_handles => []})
    end
    
    factory :ticket_rule, :class => Social::TicketRule do
      filter_data HashWithIndifferentAccess.new({:includes => ['@TestingGnip']})
      action_data HashWithIndifferentAccess.new({:group_id => nil, :product_id => 1})
    end
  end
end
