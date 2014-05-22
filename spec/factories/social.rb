if ENV["RAILS_ENV"] == "test"
  Factory.define :facebook_pages, :class => Social::FacebookPage do |f|
    f.page_id "532218423476440"
    f.profile_id 123456
    f.page_token "123456"
    f.access_token "123456"
    f.enable_page true
  end

  Factory.define :facebook_mapping, :class => Social::FacebookPageMapping do |f|
    f.facebook_page_id "532218423476440"
  end

  Factory.define :twitter_handle, :class => Social::TwitterHandle do |t|
    t.screen_name "TestingGnip"
    t.capture_dm_as_ticket true
    t.capture_mention_as_ticket true
    t.search_keys ["freshdesk", "@freshdesk"]
  end
end