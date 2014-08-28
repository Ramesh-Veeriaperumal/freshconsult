if Rails.env.test?
  FactoryGirl.define do
    factory :mobihelp_app, :class => Mobihelp::App do
      account_id 1
      sequence(:name) { |n| "Fresh App #{n}" }
      platform 1
      config HashWithIndifferentAccess.new({ :bread_crumbs =>  '10', :debug_log_count => '50', :solutions => '2', :app_review_launch_count => '5'})
    end

    factory :mobihelp_device, :class => Mobihelp::Device do
      account_id 1
      app_id 1
      user_id 1
      device_uuid "1123-123123-123123123"
    end

    factory :mobihelp_ticket, :class => Helpdesk::Ticket do
      source 8
      subject "test_subject"
      external_id "device_uuid"
    end

    factory :mobihelp_ticket_extras, :class => Mobihelp::TicketInfo do
      app_name "Application Name"
      app_version "1.0"
      os "Android"
      os_version "4.4"
      sdk_version "1.0"
      device_make "LG"
      device_model "Nexus 5"
      device_id 2
    end
  end
end