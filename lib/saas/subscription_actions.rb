class SAAS::SubscriptionActions

  FEATURES = [ :customer_slas, :business_hours, :multi_product, :facebook, :twitter, 
                :custom_domain, :multiple_emails, :css_customization, :custom_roles, 
                :dynamic_content, :mailbox, :dynamic_sections ]

  def change_plan(account, old_subscription, existing_addons)
    update_features(account, old_subscription, existing_addons)
    drop_feature_data(account)
  end
  
  def drop_feature_data(account)
    FEATURES.each do |feature_id|
      send(%(drop_#{feature_id}_data), account) unless account.features?(feature_id)
    end
  end
  
  private
    def update_features(account, old_subscription, existing_addons)
      new_addons = account.addons
      #Remove all features
      account.remove_features_of old_subscription.subscription_plan.canon_name
      remove_chat_feature(account)      # Remove chat feature if downgrade to non chat plan
      existing_addons.each do |addon|
        addon.features.collect{ |feature| account.remove_feature(feature) }
      end

      account.reload
      #Add appropriate features      
      account.add_features_of account.plan_name
      features = new_addons.collect{ |addon| addon.features }.flatten
      account.add_features(features)
      # drop chat routing data in freshchat table if downgrade to non chat routing plan
      disable_chat_routing(account) unless account.features?(:chat_routing)
    end
    
    def drop_customer_slas_data(account)
      #account.sla_policies.destroy_all(:is_default => false) #wasn't working..
      Helpdesk::SlaPolicy.destroy_all(:account_id => account.id, :is_default => false)
      account.companies.update_all(:sla_policy_id => account.sla_policies.find_by_is_default(true).id)
      #account.sla_details.update_all(:override_bhrs => true) #this too didn't work.
      account.sla_policies.find_by_is_default(true).sla_details.update_all(:override_bhrs => true)
    end

    def drop_business_hours_data(account)
      account.all_users.update_all(:time_zone => account.time_zone)
    end

    def drop_multi_product_data(account)
      account.products.destroy_all

      #We are not updating the email_config_id or product_id in Tickets model knowingly.
      #Tested, haven't faced any problem with stale email config ids or product ids.
    end
  
   def drop_facebook_data(account)
     account.facebook_pages.destroy_all
   end
   
   def drop_twitter_data(account)
    account.twitter_handles.each do |twt_handle| 
      twt_handle.cleanup
    end
    account.twitter_handles.destroy_all
   end

   def drop_custom_domain_data(account)
     account.main_portal.portal_url = nil
     account.save!
   end

   def drop_multiple_emails_data(account)
    account.global_email_configs.find(:all, :conditions => {:primary_role => false}).each{|gec| gec.destroy}
   end

   def drop_layout_customization_data(account)
    account.portal_pages.destroy_all
    account.portal_templates.each do |template|
      template.update_attributes( :header => nil, :footer => nil, :layout => nil, :head => nil)
    end
   end

   def drop_css_customization_data(account)
    account.portal_templates.update_all( :custom_css => nil, :updated_at => Time.now)
    drop_layout_customization_data(account)
   end
   
   def drop_custom_roles_data(account)
     account.technicians.each do |agent|
       if agent.privilege?(:manage_account)
         new_roles = [account.roles.find_by_name("Account Administrator")]
       elsif agent.roles.exists?(:default_role => true)
         new_roles = agent.roles.find_all_by_default_role(true)
       else
         new_roles = [account.roles.find_by_name("Agent")]
       end
       agent.roles = new_roles
       agent.save
     end
     
     Role.destroy_all(:account_id => account.id, :default_role => false )
   end

    def drop_dynamic_content_data(account)
      account.all_users.update_all(:language => account.language) 
      account.account_additional_settings.update_attributes(:supported_languages => [])
    end

    def drop_mailbox_data(account)      
      account.imap_mailboxes.destroy_all
      account.smtp_mailboxes.destroy_all
    end

    def drop_dynamic_sections_data(account)
      account.ticket_fields.each do |field|
        if field.section_field?
          field.field_options["section"] = true
          field.save
        end
      end
      account.sections.destroy_all
    end

    def remove_chat_feature(account)
      account.remove_feature(:chat) if !account.subscription.is_chat_plan? && account.features?(:chat)
    end

    def disable_chat_routing(account)
      site_id = account.chat_setting.display_id
      Resque.enqueue(Workers::Livechat, {:worker_method => "disable_routing", :site_id => site_id}) unless site_id.blank?
    end
 
end
