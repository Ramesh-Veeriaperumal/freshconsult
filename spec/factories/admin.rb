if Rails.env.test?
  Factory.define :group do |g|
    g.name "group1"
    g.description "test group one"
  end

  Factory.define :agent do |a|
    a.signature "Regards, agent1"
    a.available 1
  end

  Factory.define :portal, :class => Portal do |p|
    p.preferences "something"
  end

  Factory.define :portal_template, :class => Portal::Template do |p|
    p.preferences "something"
  end

  def create_subscriptions
    SubscriptionPlan.seed_many(:name, [
                                 { :name => 'Sprout', :amount => 15, :free_agents => 3, :day_pass_amount => 1.00 },
                                 { :name => 'Blossom', :amount => 19, :free_agents => 0, :day_pass_amount => 2.00 },
                                 { :name => 'Garden', :amount => 29, :free_agents => 0, :day_pass_amount => 2.00 },
                                 { :name => 'Estate', :amount => 49, :free_agents => 0, :day_pass_amount => 4.00 }
    ])
  end

  Factory.define :account do |p|
    create_subscriptions
    p.sequence(:name) { |n| "foo#{n}" }
    p.sequence(:full_domain) { |n| "foo#{n}.freshdesk.com" }
    p.time_zone "Chennai"
    p.sequence(:shared_secret) { |n| "f8c5eb47e87#{n}5f4ffcc19561503fa8d2" }
    p.sequence(:domain) { |n| "foo#{n}" }
    p.plan SubscriptionPlan.find_by_name("Estate")
  end

  Factory.define :dynamic_notification_templates, :class => DynamicNotificationTemplate do |e|
    e.email_notification_id "3"
    e.category "2"
    e.language "7"
    e.description "French new ticket"
    e.subject "French new ticket"
    e.outdated false
    e.active true
  end

  Factory.define :main_portal, :class => Portal do |p|
    default_preferences =  HashWithIndifferentAccess.new({:bg_color => "#efefef",:header_color => "#252525", :tab_color => "#006063"})
    locale =  I18n.default_locale
    p.sequence(:name) { |n| "foo#{n}" }
    p.language locale.to_s
    p.preferences default_preferences
    p.main_portal true
  end

  Factory.define :subscription do |f|
    f.amount 49.00
  end

  Factory.define :admin_canned_responses, :class => Admin::CannedResponses::Response do |t|
    t.title "TestingCannedResponse"
    t.content_html "Test Response content"
    t.folder_id 1
  end

  Factory.define :ca_folders, :class => Admin::CannedResponses::Folder do |t|
    t.name "TestingCannedResponseFolder"
  end

  Factory.define :roles, :class => Role do |t|
    t.name "TestingRoles"
  end
  
  Factory.define :quest, :class => Quest do |t|
    t.name "TestingQuest"
  end
end