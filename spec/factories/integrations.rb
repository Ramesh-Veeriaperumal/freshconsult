if Rails.env.test?
  FactoryGirl.define do
    factory :application, :class => Integrations::Application do
      name "Test integration"
      display_name "app_name"
      listing_order 23
      options HashWithIndifferentAccess.new({ :keys_order => [:api_key, :updates], 
                  :api_key => { :type => :text, :required => true, :label => "integrations_label", :info => "integrations_info"},
                  :updates => { :type => :checkbox, :label => "integrations_updates"}
                })
      account_id 1
      application_type "application"
    end


    factory :installed_application, :class => Integrations::InstalledApplication do
      account_id 1
      configs HashWithIndifferentAccess.new({ :inputs => { :api_key => "f7e85279afcce3b6f9db71bae15c8b69", :updates => 1} })
    end

    factory :authorization, :class => Authorization do
      provider "facebook"
      uid "12345678"
      user_id 2
      account_id 1
    end

    factory :integrated_resource, :class => Integrations::IntegratedResource do
      installed_application_id 5
      remote_integratable_id "FD-1"
      local_integratable_id 1
      local_integratable_type "issue-tracking"
      account_id 1
    end

    factory :widget, :class => Integrations::Widget do
      name "Test Application"
      description "Test description"
      script "script"
      application_id 1
      options HashWithIndifferentAccess.new({:display_in_pages => [:helpdesk_tickets_show_page_side_bar]})
    end
  end

  Factory.define :integration_user_credential, :class => Integrations::UserCredential do |t|
    t.installed_application_id 1
    t.user_id 1
    t.auth_info HashWithIndifferentAccess.new({ :refresh_token => "1/tpO82YgF2AsCnQup7SCYN1hOlk6RBHL4iyaX-oaBkRw", 
                      :oauth_token => "ya29.LgA1EMj53KSvWhoAAABtT8Nt-ZdsGJXa7bfxXn7pVkzOsLnFW9eFQCIArfLfjg", 
                      :email => "sathish@freshdesk.com"})
    t.account_id 1
  end

  Factory.define :create_webhooks, :class => ApiWebhooksController do |t|
    t.name "Test_Webhook"
    t.description "Test_description"
    t.match_type "any"
    t.filter_data "Test data"
    t.action_data "Test action data"
    t.account_id 1
    t.rule_type 13
    t.active 1
  end

  
end