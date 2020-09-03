class SAAS::SubscriptionEventActions

  attr_accessor :account, :old_plan, :add_ons, :new_plan, :existing_add_ons, :skipped_features

  DROP_DATA_FEATURES_V2 = [:create_observer, :supervisor, :add_watcher, :custom_ticket_views, :custom_apps,
                           :custom_ticket_fields, :custom_company_fields, :custom_contact_fields, :occasional_agent,
                           :advanced_twitter, :advanced_facebook, :rebranding, :customer_slas, :multi_timezone,
                           :multi_product, :multiple_emails, :link_tickets_toggle, :parent_child_tickets_toggle,
                           :shared_ownership_toggle, :skill_based_round_robin, :ticket_activity_export,
                           :auto_ticket_export, :multiple_companies_toggle, :unique_contact_identifier,
                           :support_bot, :custom_dashboard, :round_robin, :round_robin_load_balancing,
                           :hipaa, :agent_scope, :public_url_toggle, :custom_password_policy,
                           :scenario_automation, :personal_canned_response, :marketplace,
                           :custom_domain, :css_customization, :field_service_management, :field_service_management_toggle,
                           :custom_roles, :dynamic_sections, :custom_survey, :mailbox,
                           :helpdesk_restriction_toggle, :ticket_templates, :custom_source,
                           :round_robin_load_balancing, :multi_timezone, :custom_translations,
                           :sitemap, :article_versioning, :suggested_articles_count, :unlimited_multi_product, :article_approval_workflow,
                           :fb_ad_posts, :segments, :agent_assist_ultimate, :agent_assist_lite, :solutions_templates].freeze


  ADD_DATA_FEATURES_V2  = [:link_tickets_toggle, :parent_child_tickets_toggle, :multiple_companies_toggle,
                           :tam_default_fields, :smart_filter, :contact_company_notes, :unique_contact_identifier, :custom_dashboard,
                           :personal_canned_response, :round_robin, :field_service_management, :multi_language, :article_versioning,
                           :agent_assist_ultimate, :solutions_templates].freeze

  DROP  = "drop"
  ADD   = "add"
  DEFAULT_DAY_PASS_LIMIT = 3

  TOGGLES_AND_FEATURES = [[:field_service_management_toggle, :field_service_management]].freeze

  ####################################################################################################################
  #ideally we need to initialize this class with account object, old subscription object and addons
  #
  #change plan will enqueue a job to sidekiq to handle data deletion if its a downgrade.
  ####################################################################################################################
  def initialize(account, old_plan = nil, add_ons = [], features_to_skip = [])
    @account     = account || Account.current
    @new_plan    = Account.current.subscription
    @old_plan    = old_plan
    set_existing_addon_feature(add_ons)
    @skipped_features = features_to_skip

    Rails.logger.info "Empty account object passed to SubscriptionEventActions :: Account - #{Account.current.inspect}" if account.nil?
    Rails.logger.info "Initialising SubscriptionEventActions :: account -> #{account.inspect} ; @account -> #{@account.inspect} ;
                       @newplan -> #{@new_plan.inspect} ; @old_plan -> #{old_plan.inspect}"
  end

  def change_plan
    
    if plan_changed?
      remove_old_plan_db_features if old_plan.present?
      reset_plan_features
      remove_chat_feature
      add_new_plan_features
      handle_collab_feature
      disable_chat_routing unless account.has_feature?(:chat_routing)
      handle_daypass if recalculate_daypass_enabled?
      change_api_limit if ( account.fluffy_integration_enabled? && !account.fluffy_addons_enabled? )
      account.change_fluffy_email_limit if account.fluffy_email_enabled? && !account.fluffy_addons_enabled?
    end

    if add_ons_changed?
      to_be_added = account_add_ons - existing_add_ons
      to_be_removed = existing_add_ons - account_add_ons
      if skipped_features.present?
        to_be_added.reject! { |feature| skipped_features.include?(feature) }
        to_be_removed.reject! { |feature| skipped_features.include?(feature) }
      end
      
      #add on removal case. we need to remove the feature in this case.
      to_be_removed.each do |addon|
        next if plan_features.include?(addon) # Don't remove features which are all related to current plan

        begin
          Rails.logger.debug "ADDON::REMOVED with feature, #{addon}"
          account.reset_feature(addon)
          reset_settings_dependent_on_feature(addon) if account.launched?(:feature_based_settings)
        rescue StandardError => e
          Rails.logger.error("Exception while revoking addon feature addon: \
            #{addon}, error: #{e.backtrace}")
        end
      end
      #to add new addons thats coming in to get added
      to_be_added.each do |addon|
        begin
          Rails.logger.debug "ADDON::ADDED with feature, #{addon}"
          account.set_feature(addon)
          add_settings_dependent_on_feature(feature) if account.launched?(:feature_based_settings)
        rescue StandardError => e
          Rails.logger.error "Exception while revoking addon feature acc_id: \
            #{account.id} addon: #{addon}, error: #{e.backtrace}"
        end
      end
      account.save
    end
    
    if plan_changed? || add_ons_changed?
      handle_feature_drop_data
      handle_feature_add_data
      handle_fluffy_feature(to_be_added, to_be_removed)
      add_implicit_features_to_new_plan
      # remove advanced ticket scopes in case of plan upgrade and signup key does not exist
      account.revoke_feature(:advanced_ticket_scopes) unless redis_key_exists?(ADVANCED_TICKET_SCOPES_ON_SIGNUP)
    end

  end

  def handle_feature_data(features, event)
    params = { features: features, action: event }
    Rails.logger.debug "#{event} data features list:: #{features.inspect} to \
      acc_id: #{account.id}"
    NewPlanChangeWorker.perform_async(params)
  end

  private

    def remove_old_plan_db_features
      old_plan_name = old_plan.subscription_plan.canon_name
      Rails.logger.debug "old db features removed for account #{account.id} :: #{old_plan_name}"
      account.remove_features_of(old_plan_name)
      account.clear_feature_from_cache
    end

    def reset_plan_features
      features_list = account.features_list
      Rails.logger.debug "List of features to reset for account #{account.id} :: #{features_list.inspect}"
      Rails.logger.debug "account add ons :: #{account_add_ons}"
      features_list.each do |feature|
        unless plan_features.include?(feature) || account_add_ons.include?(feature) || account.selectable_features_list.include?(feature) || skipped_features.include?(feature)

          next if AccountSettings::SettingsConfig[feature] && plan_features.include?(AccountSettings::SettingsConfig[feature][:feature_dependency])

          account.reset_feature(feature)
        end
      end
      account.save
    end

    def add_new_plan_features
      Rails.logger.debug "List of new plan features for account #{account.id} :: #{plan_features.inspect}"
      plan_features.delete(:support_bot) if account.revoke_support_bot?
      plan_features.delete(:lbrr_by_omniroute) if account.round_robin_capping_enabled? && !account.lbrr_by_omniroute_enabled?
      plan_features.each do |feature|
        unless skipped_features.include?(feature)
          account.set_feature(feature)
          add_settings_dependent_on_feature(feature) if account.launched?(:feature_based_settings)
        end
      end
      account.save
    end

    def plan_features
      @plan_features ||= begin
        ((::PLANS[:subscription_plans][new_plan.subscription_plan.canon_name.to_sym] &&
          ::PLANS[:subscription_plans][new_plan.subscription_plan.canon_name.to_sym][:features].dup) || []) - (UnsupportedFeaturesList || [])
      end
    end

    def add_settings_dependent_on_feature(feature)
      (AccountSettings::FeatureToSettingsMapping[feature] || []).each do |setting|
        account.set_feature(setting) if AccountSettings::SettingsConfig[setting][:default]
      end
    end

    def reset_settings_dependent_on_feature(feature)
      (AccountSettings::FeatureToSettingsMapping[feature] || []).each do |setting|
        account.reset_feature(setting)
      end
    end

    def features_list_to_drop_data
      DROP_DATA_FEATURES_V2
    end

    def features_list_to_add_data
      ADD_DATA_FEATURES_V2
    end

    def fluffy_feature_list
      Fluffy::Constants::FLUFFY_FEATURES
    end

    def similar_toggle_features
      TOGGLES_AND_FEATURES
    end

    def handle_feature_drop_data
      drop_data_features_v2 = features_list_to_drop_data.select { |feature| feature unless account.has_feature?(feature) }
      similar_toggle_features.each do |toggle, feature|
        drop_data_features_v2.delete(feature) if drop_data_features_v2.include?(toggle) && drop_data_features_v2.include?(feature)
      end
      handle_feature_data(drop_data_features_v2, DROP) if drop_data_features_v2.present?
    end

    def handle_feature_add_data
      add_data_features_v2 = features_list_to_add_data.select { |feature| feature if account.has_feature?(feature) }
      handle_feature_data(add_data_features_v2, ADD) if add_data_features_v2.present?
    end

    def handle_fluffy_feature(to_be_added, to_be_removed)
      handle_fluffy_drop_data unless ( fluffy_feature_list & (to_be_removed || []) ).empty?
      handle_fluffy_add_data unless ( fluffy_feature_list & (to_be_added || []) ).empty?
    end

    def handle_fluffy_drop_data
      drop_fluffy_features = fluffy_feature_list.select { |feature| feature unless account.has_feature?(feature) }
      Rails.logger.info "Drop fluffy feautres list:: #{drop_fluffy_features.inspect}"
      handle_feature_data(drop_fluffy_features, DROP) if drop_fluffy_features.present?
    end

    def handle_fluffy_add_data
      add_fluffy_features = fluffy_feature_list.select { |feature| feature if account.has_feature?(feature) }
      Rails.logger.info "Add fluffy feautres list:: #{add_fluffy_features.inspect}"
      handle_feature_data(add_fluffy_features, ADD) if add_fluffy_features.present?
    end

    def remove_chat_feature
      account.revoke_feature(:chat) if !account.subscription.is_chat_plan? && account.has_feature?(:chat)
    end

    def disable_chat_routing
      site_id = account.chat_setting.site_id
      LivechatWorker.perform_async({:worker_method =>"disable_routing", :siteId => site_id}) unless site_id.blank?
    end

    #This gives the latest set of add ons
    def account_add_ons
      @account_add_ons ||= account.addons.collect {|addon| addon.features}.flatten
    end

    #This is cached addons before the addons added/removed
    def set_existing_addon_feature(addons)
      @existing_add_ons ||= addons.collect {|addon| addon.features}.flatten
    end

    def add_ons_changed?
      !(@existing_add_ons & account_add_ons == @existing_add_ons and 
            account_add_ons & @existing_add_ons == account_add_ons)
    end

    def plan_changed?
      (new_plan.subscription_plan_id != old_plan.subscription_plan_id) &&
        ::PLANS[:subscription_plans][new_plan.subscription_plan.canon_name.to_sym].present?
    end

    def handle_collab_feature
      if account.has_feature?(:collaboration)
        CollabPreEnableWorker.perform_async(true)
      else
        CollabPreEnableWorker.perform_async(false)
      end
    end

    def handle_daypass
      return unless daypass_calc_needed?
      
      new_plan_dp_amount, old_plan_dp_amount = fetch_daypass_amount
      return if new_plan_dp_amount == old_plan_dp_amount

      credits_to_be_added = calc_daypass_and_credits(new_plan_dp_amount, old_plan_dp_amount)
      Billing::ChargebeeWrapper.new.add_daypass_credits(credits_to_be_added.to_i) if credits_to_be_added > 0
      daypass_config.reload
      daypass_config.try_auto_recharge
    rescue StandardError => e
      Rails.logger.info("Error while handling day_pass calculation - #{Account.current.id}-#{e.inspect}")
    end

    def daypass_calc_needed?
      daypass_config.available_passes <= DEFAULT_DAY_PASS_LIMIT || account.day_pass_purchases.blank? || !account.subscription.active?
    end

    def fetch_daypass_amount
      [@new_plan.retrieve_addon_price(:day_pass), @old_plan.retrieve_addon_price(:day_pass)]
    end

    def calc_daypass_and_credits(new_plan_dp_amount, old_plan_dp_amount)
      amount_needed = new_plan_dp_amount.to_f * daypass_config.available_passes
      dp_purchase_amount = old_plan_dp_amount.to_f * daypass_config.available_passes

      if dp_purchase_amount > amount_needed # downgrade
        dp_purchase_amount - amount_needed
      else # upgrade
        daypass_config.available_passes = (dp_purchase_amount.to_i / new_plan_dp_amount.to_i)
        daypass_config.save
        dp_purchase_amount % new_plan_dp_amount
      end
    end

    def daypass_config
      @daypass_config ||= account.day_pass_config
    end

    def recalculate_daypass_enabled?
      Account.current.recalculate_daypass_enabled?
    end

    def change_api_limit
      account.change_fluffy_api_limit if account.fluffy_enabled?
      account.change_fluffy_api_min_limit if account.fluffy_min_level_enabled?
    end

    def add_implicit_features_to_new_plan
      if account.field_service_management_toggle_enabled? && account.field_service_management_enabled?
        account.add_feature(:dynamic_sections) unless account.has_feature?(:dynamic_sections)
      end
    end
end
