if Rails.env.test?
  FactoryGirl.define do
    factory :application, :class => Integrations::Application do |t|
      name "Test integration"
      display_name "app_name"
      listing_order 23
      options HashWithIndifferentAccess.new({ :keys_order => [:api_key, :updates], 
                  :api_key => { :type => :text, :required => true, :label => "integrations_label", :info => "integrations_info"},
                  :updates => { :type => :checkbox, :label => "integrations_updates"}
                })
      application_type "application"
    end

    factory :installed_application, :class => Integrations::InstalledApplication do |t|
      #t.application_id 23
      configs HashWithIndifferentAccess.new({ :inputs => { :api_key => "f7e85279afcce3b6f9db71bae15c8b69", :updates => 1} })
    end

    factory :authorization, :class => Authorization do |t|
      provider "facebook"
      uid "12345678"
      user_id 2
    end

    factory :integrated_resource, :class => Integrations::IntegratedResource do |t|
      installed_application_id 5
      remote_integratable_id "FD-1"
      local_integratable_id 1
      local_integratable_type "issue-tracking"
    end

    factory :widget, :class => Integrations::Widget do |t|
      name "Test Application"
      description "Test description"
      script "script"
      application_id 1
      options HashWithIndifferentAccess.new({:display_in_pages => [:helpdesk_tickets_show_page_side_bar]})
    end

    factory :integration_user_credential, :class => Integrations::UserCredential do |t|
      installed_application_id 1
      user_id 1
      auth_info HashWithIndifferentAccess.new({ :refresh_token => "1/tpO82YgF2AsCnQup7SCYN1hOlk6RBHL4iyaX-oaBkRw", 
                        :oauth_token => "ya29.LgA1EMj53KSvWhoAAABtT8Nt-ZdsGJXa7bfxXn7pVkzOsLnFW9eFQCIArfLfjg", 
                        :email => "sathish@freshdesk.com"})
    end

    factory :create_webhooks, :class => ApiWebhooksController do |t|
      name "Test_Webhook"
      description "Test_description"
      match_type "any"
      filter_data "Test data"
      action_data "Test action data"
      rule_type 13
      active 1
    end
  end
end