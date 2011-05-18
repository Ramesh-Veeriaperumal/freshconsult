class SAAS::SubscriptionActions
  def change_plan(account, old_subscription)
    update_features(account, old_subscription)
    
    case account.plan_name
    when :basic
      drop_custom_sla(account)
      update_timezone_to_users(account)
      drop_additional_emails(account)
    when :pro
      update_timezone_to_users(account)
      drop_additional_emails(account)
    end
  end
  
  private
    def update_features(account, old_subscription)
      account.remove_features_of old_subscription.subscription_plan.canon_name
      account.reload
      account.add_features_of account.plan_name
    end
    
    def drop_custom_sla(account)
      #account.sla_policies.destroy_all(:is_default => false) #wasn't working..
      Helpdesk::SlaPolicy.destroy_all(:account_id => account.id, :is_default => false)
      account.customers.update_all(:sla_policy_id => account.sla_policies.find_by_is_default(true).id)
      #account.sla_details.update_all(:override_bhrs => true) #this too didn't work.
      account.sla_policies.find_by_is_default(true).sla_details.update_all(:override_bhrs => true)
    end

    def update_timezone_to_users(account)
      account.all_users.update_all(:time_zone => account.time_zone)
    end

    def drop_additional_emails(account)
      EmailConfig.destroy_all(:account_id => account.id, :primary_role => false)
      #We are not updating the email_config_id in Tickets model knowingly.
      #Tested, haven't faced any problem with stale email config ids.
    end
end
