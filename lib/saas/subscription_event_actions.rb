class SAAS::SubscriptionEventActions

  attr_accessor :account, :old_plan, :add_ons, :new_plan, :existing_add_ons

  DROP_DATA_FEATURES_V2 = [:create_observer, :supervisor, :add_watcher, :custom_ticket_views, :custom_apps,
                           :custom_ticket_fields, :custom_company_fields, :custom_contact_fields, :occasional_agent,
                           :basic_twitter, :basic_facebook, :rebranding, :customer_slas, :multi_timezone,
                           :multi_product, :multiple_emails, :link_tickets_toggle, :parent_child_tickets_toggle,
                           :shared_ownership_toggle, :skill_based_round_robin, :ticket_activity_export,
                           :auto_ticket_export, :multiple_companies_toggle, :unique_contact_identifier,
                           :support_bot, :custom_dashboard, :round_robin, :round_robin_load_balancing,
                           :hipaa, :agent_scope, :public_url_toggle, :custom_password_policy,
                           :scenario_automation].freeze

  ADD_DATA_FEATURES_V2  = [:link_tickets_toggle, :parent_child_tickets_toggle, :multiple_companies_toggle,
                           :tam_default_fields, :smart_filter, :contact_company_notes, :unique_contact_identifier, :custom_dashboard].freeze

  DASHBOARD_PLANS = [ SubscriptionPlan::SUBSCRIPTION_PLANS[:estate], 
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:forest],
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_jan_17], 
                      SubscriptionPlan::SUBSCRIPTION_PLANS[:forest_jan_17] ].freeze

  DROP  = "drop"
  ADD   = "add"

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
      reset_plan_features
      remove_chat_feature
      add_new_plan_features
      handle_custom_dasboard_launch
      handle_collab_feature
      add_chat_feature
      disable_chat_routing unless account.has_feature?(:chat_routing)
    end

    if add_ons_changed?
      to_be_added = account_add_ons - existing_add_ons
      to_be_removed = existing_add_ons - account_add_ons
      
      #add on removal case. we need to remove the feature in this case.
      to_be_removed.each do |addon|
        next if plan_features.include?(addon) # Don't remove features which are all related to current plan
        account.revoke_feature(addon) rescue nil
      end
      #to add new addons thats coming in to get added
      to_be_added.each do |addon|
        account.add_feature(addon) rescue nil
      end
    end
    
    if plan_changed? || add_ons_changed?
      handle_feature_drop_data
      handle_feature_add_data
    end

  end

  private

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


    def handle_feature_data(features_data, event)
      NewPlanChangeWorker.perform_async({:features => features_data, :action => event})
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
      new_plan.subscription_plan_id != old_plan.subscription_plan_id
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
end
