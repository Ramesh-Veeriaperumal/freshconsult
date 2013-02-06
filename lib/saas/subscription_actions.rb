class SAAS::SubscriptionActions
  def change_plan(account, old_subscription)
    update_features(account, old_subscription)
    case account.plan_name
    when :sprout
      drop_custom_sla(account)
      update_timezone_to_users(account)
      drop_products(account)
      drop_facebook_pages(account)
      drop_twitter_handles(account)
      drop_custom_domain(account)
      drop_multiple_emails(account)
    when :blossom
      drop_custom_sla(account)
      update_timezone_to_users(account)
      drop_products(account)
    end
  end
  
  def change_to_free(account, old_subscription)
    free_subscription_plan = SubscriptionPlan.find_by_name(SubscriptionPlan::SUBSCRIPTION_PLANS[:free])
    old_subscription.subscription_plan = free_subscription_plan
    old_subscription.save!
  end
  
  private
    
    def drop_except_account_admin(account)
      account.users.update_all({:deleted => true}, ["user_role in (?,?)", User::USER_ROLES_KEYS_BY_TOKEN[:admin],User::USER_ROLES_KEYS_BY_TOKEN[:poweruser]] )
    end
    
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

    def drop_products(account)
      account.products.destroy_all

      #We are not updating the email_config_id or product_id in Tickets model knowingly.
      #Tested, haven't faced any problem with stale email config ids or product ids.
  end
  
   def drop_facebook_pages(account)
     account.facebook_pages.destroy_all
   end
   
   def drop_twitter_handles(account)
     account.twitter_handles.destroy_all
   end

   def drop_custom_domain(account)
     account.main_portal.portal_url = nil
     account.save!
   end

   def drop_multiple_emails(account)
    account.global_email_configs.find(:all, :conditions => {:primary_role => false}).each{|gec| gec.destroy}
   end
 
end
