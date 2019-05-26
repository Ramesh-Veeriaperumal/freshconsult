class SAAS::SubscriptionEventActions

  attr_accessor :account, :old_plan, :add_ons, :new_plan, :existing_add_ons

  DROP_DATA_FEATURES_V2 = [:create_observer, :supervisor, :add_watcher, :custom_ticket_views, :custom_apps,
                           :custom_ticket_fields, :custom_company_fields, :custom_contact_fields, :occasional_agent,
                           :advanced_twitter, :advanced_facebook, :rebranding, :customer_slas, :multi_timezone,
                           :multi_product, :multiple_emails, :link_tickets_toggle, :parent_child_tickets_toggle,
                           :shared_ownership_toggle, :skill_based_round_robin, :ticket_activity_export,
                           :auto_ticket_export, :multiple_companies_toggle, :unique_contact_identifier, :support_bot, :custom_dashboard,
                           :round_robin, :round_robin_load_balancing, :hipaa, :agent_scope, :public_url_toggle,
                           :scenario_automation, :personal_canned_response, :custom_password_policy, :marketplace,
                           :custom_domain, :css_customization, :custom_roles,
                           :dynamic_sections, :custom_survey, :mailbox,
                           :helpdesk_restriction_toggle, :ticket_templates,
                           :round_robin_load_balancing, :multi_timezone, :field_service_management].freeze

  ADD_DATA_FEATURES_V2  = [:link_tickets_toggle, :parent_child_tickets_toggle, :multiple_companies_toggle, 
                           :tam_default_fields, :smart_filter, :contact_company_notes, :unique_contact_identifier, :custom_dashboard,
                           :personal_canned_response, :round_robin, :field_service_management].freeze

  DASHBOARD_PLANS = [ SubscriptionPlan::SUBSCRIPTION_PLANS[:estate],
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:forest],
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_jan_17],
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:forest_jan_17],
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_jan_19],
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_omni_jan_19],
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:forest_jan_19] ].freeze

  DROP  = "drop"
  ADD   = "add"
  DEFAULT_DAY_PASS_LIMIT = 3

  SELECTABLE_DB_FEATURES = (Account::SELECTABLE_FEATURES.keys +
                           Account::TEMPORARY_FEATURES.keys +
                           Account::ADMIN_CUSTOMER_PORTAL_FEATURES.keys).freeze

  ####################################################################################################################
  #ideally we need to initialize this class with account object, old subscription object and addons
  #
  #change plan will enqueue a job to sidekiq to handle data deletion if its a downgrade.
  ####################################################################################################################
  def initialize(account, old_plan = nil, add_ons = [])
    @account     = account || Account.current
    @new_plan    = Account.current.subscription
    @old_plan    = old_plan
    set_existing_addon_feature(add_ons)
  end

  def change_plan
    
    if plan_changed?
      remove_old_plan_db_features if old_plan.present?
      reset_plan_features
      remove_chat_feature
      add_new_plan_features
      handle_custom_dasboard_launch
      handle_collab_feature
      add_chat_feature
      disable_chat_routing unless account.has_feature?(:chat_routing)
      handle_daypass if recalculate_daypass_enabled?
    end

    if add_ons_changed?
      to_be_added = account_add_ons - existing_add_ons
      to_be_removed = existing_add_ons - account_add_ons
      
      #add on removal case. we need to remove the feature in this case.
      to_be_removed.each do |addon|
        next if plan_features.include?(addon) # Don't remove features which are all related to current plan

        begin
          if reset_in_db?(addon)
            Rails.logger.debug "ADDON::REMOVED as db feature, #{addon}"
            account.remove_feature(feature)
          else
            account.revoke_feature(addon)
          end
        rescue StandardError => e
          Rails.logger.error("Exception while revoking addon feature addon: \
            #{addon}, error: #{e.backtrace}")
        end
      end
      #to add new addons thats coming in to get added
      to_be_added.each do |addon|
        begin
          if reset_in_db?(addon)
            Rails.logger.debug "ADDON::ADDED as db feature, #{addon}"
            account.add_features(addon)
          else
            account.add_feature(addon)
          end
        rescue StandardError => e
          Rails.logger.error "Exception while revoking addon feature acc_id: \
            #{account.id} addon: #{addon}, error: #{e.backtrace}"
        end
      end
    end
    
    if plan_changed? || add_ons_changed?
      handle_feature_drop_data
      handle_feature_add_data
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
      account.remove_features_of(old_plan.subscription_plan.canon_name)
      account.clear_feature_from_cache
    end

    def reset_in_db?(feature)
      SELECTABLE_DB_FEATURES.include?(feature) && !account.launched?(:db_to_bitmap_features_migration_phase2)
    end

    def reset_plan_features
      account.features_list.each do |feature|
        account.reset_feature(feature) unless(plan_features.include?(feature) || 
          account_add_ons.include?(feature) || 
          account.selectable_features_list.include?(feature))
      end
      account.save
    end

    def add_new_plan_features
      plan_features.delete(:support_bot) if account.revoke_support_bot?
      plan_features.each do |feature|
        account.set_feature(feature)
      end
      account.save
    end

    def plan_features
      @plan_features ||= ::PLANS[:subscription_plans][
        new_plan.subscription_plan.canon_name.to_sym][:features].dup
    end

    def features_list_to_drop_data
      DROP_DATA_FEATURES_V2
    end

    def features_list_to_add_data
      ADD_DATA_FEATURES_V2
    end

    def handle_feature_drop_data
      drop_data_features_v2 = features_list_to_drop_data.select { |feature| feature unless account.has_feature?(feature) }
      Rails.logger.info "Drop data feautres list:: #{drop_data_features_v2.inspect}"
      handle_feature_data(drop_data_features_v2, DROP) if drop_data_features_v2.present?
    end

    def handle_feature_add_data
      add_data_features_v2 = features_list_to_add_data.select { |feature| feature if account.has_feature?(feature) }
      Rails.logger.info "Add data feautres list:: #{add_data_features_v2.inspect}"
      handle_feature_data(add_data_features_v2, ADD) if add_data_features_v2.present?
    end

    def remove_chat_feature
      account.revoke_feature(:chat) if !account.subscription.is_chat_plan? && account.has_feature?(:chat)
    end

    # Need to be removed once we won't support live chat
    def add_chat_feature
      account.add_feature(:chat) if new_plan_has_livechat? && !account.has_feature?(:chat) &&  account.chat_setting.site_id.present?
    end

    def new_plan_has_livechat?
      account.subscription.is_chat_plan?
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

    def handle_custom_dasboard_launch
      is_dashboard_plan = dashboard_plan?
        if is_dashboard_plan
          CountES::IndexOperations::EnableCountES.perform_async({ :account_id => account.id })
        else
          [:admin_dashboard, :agent_dashboard, :supervisor_dashboard].each do |f|
            account.features.countv2_reads.destroy
            account.rollback(f)
          end
        end
    end

    def dashboard_plan?
      DASHBOARD_PLANS.include?(new_plan.subscription_plan.name)
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
      daypass_config = account.day_pass_config
      daypass_config.available_passes > DEFAULT_DAY_PASS_LIMIT && account.day_pass_purchases.present? && account.subscription.active?
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
end
