class SAAS::SubscriptionActions

  DROP_DATA_FEATURES  = [ :customer_slas, :multiple_business_hours, :multi_product, 
    :facebook, :twitter, :custom_domain, :multiple_emails, :css_customization, 
    :custom_roles, :dynamic_content, :mailbox, :dynamic_sections, :custom_survey, 
    :round_robin, :multi_language, :helpdesk_restriction_toggle, :ticket_templates, 
    :multiple_companies_toggle, :round_robin_load_balancing ]

  ADD_DATA_FEATURES   = [:round_robin]

  DROP  = "drop"
  ADD   = "add"

  def change_plan(account, old_subscription, existing_addons)
    update_features(account, old_subscription, existing_addons)

    drop_data_features = DROP_DATA_FEATURES.select { |feature| feature unless account.features?(feature) }
    add_data_features = ADD_DATA_FEATURES.select { |feature| feature if account.features?(feature) }

    drop_feature_data(drop_data_features)
    add_feature_data(add_data_features)
    #for new pricing plan. we ll remove basic social and basic twitter if facebook or twitter feature isnt available after downgrade annd
    #add back when they upgrade.
    [:facebook, :twitter].each do |f|
      feature_name = "basic_#{f}".to_sym
      if account.features?(f)
        account.add_feature(feature_name)
      else
        account.revoke_feature(feature_name)
      end
    end
  end

  def drop_feature_data(drop_data_features)
    PlanChangeWorker.perform_async({:features => drop_data_features, :action => DROP})
  end

  def add_feature_data(add_data_features)
    PlanChangeWorker.perform_async({:features => add_data_features, :action => ADD})
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

    def remove_chat_feature(account)
      account.remove_feature(:chat) if !account.subscription.is_chat_plan? && account.features?(:chat)
    end

    def disable_chat_routing(account)
      site_id = account.chat_setting.site_id
      LivechatWorker.perform_async({:worker_method =>"disable_routing", :siteId => site_id}) unless site_id.blank?
    end
 
end
