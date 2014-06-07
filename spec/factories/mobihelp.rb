if ENV["RAILS_ENV"] == "test"
  Factory.define :mobihelp_app, :class => Mobihelp::App do |t|
    t.account_id 1
    t.name "Fresh App"
    t.platform 1
    t.config HashWithIndifferentAccess.new({ :bread_crumbs =>  '10', :debug_log_count => '50', :solutions => '2', :app_review_launch_count => '5'})
  end

  Factory.define :mobihelp_device, :class => Mobihelp::Device do |t|
    t.account_id 1
    t.app_id 1
    t.user_id 1
    t.device_uuid "1123-123123-123123123"
  end

  Factory.define :mobihelp_ticket, :class => Helpdesk::Ticket do |t|
    t.source 8
    t.subject "test_subject"
    t.external_id "device_uuid"
  end

  Factory.define :mobihelp_ticket_extras, :class => Mobihelp::TicketInfo do |t|
    t.app_name "Application Name"
    t.app_version "1.0"
    t.os "Android"
    t.os_version "4.4"
    t.sdk_version "1.0"
    t.device_make "LG"
    t.device_model "Nexus 5"
    t.device_id 2
  end
end