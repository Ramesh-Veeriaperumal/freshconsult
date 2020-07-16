class MixpanelObserver < ActiveRecord::Observer
  extend ::NewRelic::Agent::MethodTracer
  include MixpanelWrapper

  observe Account, Admin::DataImport, Agent, DataExport, EmailConfig, Integrations::InstalledApplication, Product, Social::TwitterHandle, Subscription, VaRule

  MODELS = {
    :subscription => "Subscription",
    :account => "Account",
    :admin_import => "Admin::DataImport",
    :integrations => "Integrations::InstalledApplication"
  } 


  IMPORT = {
    :zendesk => 1
  }

  EVENTS = {
    count: ['Social::TwitterHandle', 'Agent', 'EmailConfig', 'Product', 'VaRule']
  }
  
  
  def after_commit(model)
    if model.safe_send(:transaction_include_action?, :create)
      send_account_created_event(model) if model.class.name.eql?(MODELS[:account])
      send_model_event(model)
    elsif model.safe_send(:transaction_include_action?, :destroy)
      if model.class.name == MODELS[:integrations]
        ::MixpanelWrapper.send_to_mixpanel(model.class.name, {:enabled => false})
      end
    end
  end

  def after_update(model)
    send_plan_update_event(model) if model.class.name.eql?(MODELS[:subscription])
  end

  private
    def send_account_created_event(model)
      data = { :email => model.admin_email, :domain => model.full_domain,
       :plan => model.subscription.subscription_plan.name, :state => model.subscription.state } 
      ::MixpanelWrapper.send_to_mixpanel(model.class.name, data)
    end

    def send_model_event(model)
      if !check_valid_model(model) 
        ::MixpanelWrapper.send_to_mixpanel(model.class.name, fetch_data(model))
      end
    end

    #Do not trigger events for these model creations.
    def check_valid_model(model)
      (MODELS[:account] == model.class.name) ||
        (MODELS[:subscription] == model.class.name) || 
        (MODELS[:admin_import] == model.class.name && model.source != IMPORT[:zendesk])
    end

    def fetch_data(model)
      if EVENTS[:count].include?(model.class.name)
        { :count => model.class.count(:all, :conditions => {:account_id => model.account_id}) }
      else
        { :enabled => true }
      end
    end

    def send_zendesk_import_event(model)
      if model.source == IMPORT[:zendesk]
        ::MixpanelWrapper.send_to_mixpanel(model.class.name)
      end
    end

    def send_plan_update_event(model)
      data = {:subscription => model.attributes.to_json, :changes => model.changes.clone}
      ::MixpanelWrapper.send_to_mixpanel(model.class.name, data)
    end

    add_method_tracer :send_account_created_event, 'Custom/Mixpanel/account_event'
    add_method_tracer :send_model_event, 'Custom/Mixpanel/model_event'
    add_method_tracer :send_plan_update_event, 'Custom/Mixpanel/update_event'
end
