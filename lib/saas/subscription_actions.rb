class SAAS::SubscriptionActions

  FEATURES = [ :customer_slas, :multiple_business_hours, :multi_product, :facebook, :twitter, 
                :custom_domain, :multiple_emails, :css_customization, :custom_roles, 
                :dynamic_content, :mailbox, :dynamic_sections, :custom_survey ]

  def change_plan(account, old_subscription, existing_addons)
    update_features(account, old_subscription, existing_addons)
    drop_feature_data(account)
  end
  
  def drop_feature_data(account)
    features_to_drop = FEATURES.select { |feature_id| feature_id unless account.features?(feature_id) }
    PlanChangeWorker.perform_async(features_to_drop)
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

    def drop_dynamic_sections_data(account)
      account.ticket_fields.each do |field|
        if field.section_field?
          field.field_options["section"] = false
          field.save
        end
      end
      account.sections.destroy_all
    end

    def drop_custom_survey_data(account)
      if account.default_survey_enabled?
        account.custom_surveys.default.first.activate if account.active_custom_survey_from_cache.present?
      else
        account.custom_surveys.deactivate_active_surveys
      end
    end

    def remove_chat_feature(account)
      account.remove_feature(:chat) if !account.subscription.is_chat_plan? && account.features?(:chat)
    end

    def disable_chat_routing(account)
      site_id = account.chat_setting.display_id
      Resque.enqueue(Workers::Livechat, {:worker_method => "disable_routing", :site_id => site_id}) unless site_id.blank?
    end
 
end
