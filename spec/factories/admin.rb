if Rails.env.test?
  FactoryGirl.define do
    factory :group do
      sequence(:name) { |n| "Group#{n}" }
      description { Faker::Lorem.sentence(10) }
    end

    factory :agent do
      signature "Regards, agent1"
      available 1
    end

    factory :portal, :class => Portal do
      preferences "something"
    end

#    factory :portal_template, :class => Portal::Template do
#      preferences "something"
#    end


    factory :account do
#      create_subscriptions
      sequence(:name) { |n| "foo#{n}" }
      sequence(:full_domain) { |n| "foo#{n}.freshdesk.com" }
      time_zone "Chennai"
      sequence(:shared_secret) { |n| "f8c5eb47e87#{n}5f4ffcc19561503fa8d2" }
      sequence(:domain) { |n| "foo#{n}" }
      plan SubscriptionPlan.find_by_name("Estate")
    end

    factory :dynamic_notification_templates, :class => DynamicNotificationTemplate do
      email_notification_id "3"
      category "2"
      language "7"
      description "French new ticket"
      subject "French new ticket"
      outdated false
      active true
    end

#    factory :main_portal, :class => Portal do
#      default_preferences =  HashWithIndifferentAccess.new({:bg_color => "#efefef",:header_color => "#252525", :tab_color => "#006063"})
#      locale =  I18n.default_locale
#      sequence(:name) { |n| "foo#{n}" }
#      language locale.to_s
#      preferences default_preferences
#      main_portal true
#    end
#
#    factory :subscription do
#      amount 49.00
#    end
#
    factory :admin_canned_responses, :class => Admin::CannedResponses::Response do
      title "TestingCannedResponse"
      content_html "Test Response content"
      folder_id 1
    end
#
    factory :ca_folders, :class => Admin::CannedResponses::Folder do
      name "TestingCannedResponseFolder"
    end
    
    factory :roles, :class => Role do
      name "TestingRoles"
    end
    
    factory :quest, :class => Quest do
      name "TestingQuest"
    end
  end
end