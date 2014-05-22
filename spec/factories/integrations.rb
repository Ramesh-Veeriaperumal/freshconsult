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
    t.application_id 23
    t.account_id 1
    t.configs HashWithIndifferentAccess.new({ :inputs => { :api_key => "f7e85279afcce3b6f9db71bae15c8b69", :updates => 1} })
  end

  Factory.define :authorization, :class => Authorization do |t|
    t.provider "facebook"
    t.uid "12345678"
    t.user_id 2
    t.account_id 1
  end
  
end