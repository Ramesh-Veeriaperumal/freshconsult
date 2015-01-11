if Rails.env.test?
  FactoryGirl.define do
    factory :mobihelp_app, :class => Mobihelp::App do |t|
      sequence(:name) { |n| "Fresh App #{n}" }
      platform 1
      category_ids ["2"]
      config HashWithIndifferentAccess.new({ :bread_crumbs =>  Mobihelp::App::DEFAULT_BREADCRUMBS_COUNT, :debug_log_count => Mobihelp::App::DEFAULT_LOGS_COUNT, :app_review_launch_count => Mobihelp::App::DEFAULT_APP_REVIEW_LAUNCH_COUNT})
    end

    factory :mobihelp_device, :class => Mobihelp::Device do |t|
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

    factory :mobihelp_app_solutions, :class => Mobihelp::AppSolution do |m|
      app_id 1
      category_id 1
      position 1
    end
  end
end