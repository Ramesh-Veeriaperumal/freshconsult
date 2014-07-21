if ENV["RAILS_ENV"] == "test"
  Factory.define :application, :class => Integrations::Application do |t|
    t.name "Test integration"
    t.display_name "app_name"
    t.listing_order 23
    t.options HashWithIndifferentAccess.new({ :keys_order => [:api_key, :updates], 
                :api_key => { :type => :text, :required => true, :label => "integrations_label", :info => "integrations_info"},
                :updates => { :type => :checkbox, :label => "integrations_updates"}
              })
    t.account_id 1
    t.application_type "application"
  end

  Factory.define :installed_application, :class => Integrations::InstalledApplication do |t|
    #t.application_id 23
    t.account_id 1
    t.configs HashWithIndifferentAccess.new({ :inputs => { :api_key => "f7e85279afcce3b6f9db71bae15c8b69", :updates => 1} })
  end

  Factory.define :authorization, :class => Authorization do |t|
    t.provider "facebook"
    t.uid "12345678"
    t.user_id 2
    t.account_id 1
  end

  Factory.define :integrated_resource, :class => Integrations::IntegratedResource do |t|
    t.installed_application_id 5
    t.remote_integratable_id "FD-1"
    t.local_integratable_id 1
    t.local_integratable_type "issue-tracking"
    t.account_id 1
  end

  Factory.define :widget, :class => Integrations::Widget do |t|
    t.name "Test Application"
    t.description "Test description"
    t.script "script"
    t.application_id 1
    t.options HashWithIndifferentAccess.new({:display_in_pages => [:helpdesk_tickets_show_page_side_bar]})
  end

  Factory.define :integration_user_credential, :class => Integrations::UserCredential do |t|
    t.installed_application_id 1
    t.user_id 1
    t.auth_info HashWithIndifferentAccess.new({ :refresh_token => "1/tpO82YgF2AsCnQup7SCYN1hOlk6RBHL4iyaX-oaBkRw", 
                      :oauth_token => "ya29.LgA1EMj53KSvWhoAAABtT8Nt-ZdsGJXa7bfxXn7pVkzOsLnFW9eFQCIArfLfjg", 
                      :email => "sathish@freshdesk.com"})
    t.account_id 1
  end

  
end