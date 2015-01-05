if Rails.env.test?
  FactoryGirl.define do
    factory :mobihelp_app, :class => Mobihelp::App do |t|
      t.sequence(:name) { |n| "Fresh App #{n}" }
      t.platform 1
      t.category_ids ["2"]
      t.config HashWithIndifferentAccess.new({ :bread_crumbs =>  Mobihelp::App::DEFAULT_BREADCRUMBS_COUNT, :debug_log_count => Mobihelp::App::DEFAULT_LOGS_COUNT, :app_review_launch_count => Mobihelp::App::DEFAULT_APP_REVIEW_LAUNCH_COUNT})
    end

    factory :mobihelp_device, :class => Mobihelp::Device do |t|
      t.app_id 1
      t.user_id 1
      t.device_uuid "1123-123123-123123123"
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
      m.app_id 1
      m.category_id 1
      m.position 1
    end
  end
end