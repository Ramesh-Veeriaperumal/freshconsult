if ENV["RAILS_ENV"] == "test"
  Factory.define :facebook_pages, :class => Social::FacebookPage do |f|
    f.page_id {(Time.now.utc.to_f*100000).to_i}
    f.profile_id 123456
    f.page_token "123456"
    f.access_token "123456"
    f.enable_page true
    f.import_visitor_posts false
    f.import_company_posts false
    f.realtime_subscription true
  end

  Factory.define :facebook_mapping, :class => Social::FacebookPageMapping do |f|
    f.facebook_page_id "532218423476440"
  end

  Factory.define :twitter_handle, :class => Social::TwitterHandle do |t|
    t.screen_name "TestingGnip"
    t.capture_dm_as_ticket true
    t.capture_mention_as_ticket false
    t.search_keys []
  end
  
  Factory.define :twitter_stream, :class => Social::TwitterStream do |t|
    t.name "Custom Social Stream"
    t.type "Social::TwitterStream"
    t.includes ["Freshdesk"]
    t.excludes []
    t.data HashWithIndifferentAccess.new({:kind => "Custom" })
    t.filter HashWithIndifferentAccess.new({:exclude_twitter_handles => []})
  end
  
  Factory.define :ticket_rule, :class => Social::TicketRule do |t|
    t.filter_data HashWithIndifferentAccess.new({:includes => ['@TestingGnip']})
    t.action_data HashWithIndifferentAccess.new({:group_id => nil, :product_id => 1})
  end
  
end
