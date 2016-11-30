class SAAS::SubscriptionEventActions

  attr_accessor :account, :old_plan, :add_ons, :new_plan, :existing_add_ons

  DROP_DATA_FEATURES_V2 = [:observer, :supervisor, :add_watcher, :custom_ticket_views, :custom_apps, :custom_ticket_fields, 
                            :custom_company_fields, :custom_contact_fields, :occasional_agent, :basic_twitter, :basic_facebook]

  ####################################################################################################################
  #ideally we need to initialize this class with account object, old subscription object and addons 
  #
  #change plan will enqueue a job to sidekiq to handle data deletion if its a downgrade.
  ####################################################################################################################
  def initialize(account, old_plan, add_ons = [])
    @account     = account || Account.current
    @new_plan    = Account.current.subscription
    @old_plan    = old_plan
    #set_existing_on_feature(add_ons)
  end

  def change_plan
    if plan_changed?
      plan_features = ::PLANS[:subscription_plans][new_plan.subscription_plan.canon_name.to_sym][:features]
      account.features_list.each do |feature|
        account.reset_feature(feature) unless plan_features.include?(feature) || account_add_ons.include?(feature)
      end
      account.save
      remove_chat_feature
      plan_features.each do |feature|
        account.set_feature(feature)
      end
      account.save
      disable_chat_routing unless account.has_feature?(:chat_routing)
    end

    #uncomment when we implement add ons for this set or move existing features handle to here which inturn will bring those addons here.
    # if add_ons_changed?
    #   #to add new addons thats coming in to get added
    #   account_add_ons.each do |addon|
    #     account.add_feature(addon) unless existing_add_ons.include?(addon)
    #   end

    #   #add on removal case. we need to remove the feature in this case.
    #   existing_add_ons.each do |addon|
    #     account.revoke_feature(addon) unless account.has_feature?(addon)
    #   end
    # end
    
    handle_feature_drop_data if plan_changed? #|| add_ons_changed?

  end

  private

    def handle_feature_drop_data
      drop_data_features_v2 = DROP_DATA_FEATURES_V2.select { |feature| feature unless account.has_feature?(feature) }
      Rails.logger.info "Drop data feautres list:: #{drop_data_features_v2.inspect}"
      handle_feature_data(drop_data_features_v2) if drop_data_features_v2.present?
    end

    def handle_feature_data(features_to_drop_data)
      NewPlanChangeWorker.perform_async({:features => features_to_drop_data})
    end

    def remove_chat_feature
      account.revoke_feature(:chat) if !account.subscription.is_chat_plan? && account.has_feature?(:chat)
    end

    def disable_chat_routing
      site_id = account.chat_setting.site_id
      LivechatWorker.perform_async({:worker_method =>"disable_routing", :siteId => site_id}) unless site_id.blank?
    end

    def account_add_ons
      @account_add_ons ||= account.addons.collect {|addon| addon.features}.flatten
    end

    def set_existing_on_feature(addons)
      @existing_add_ons ||= addons.collect {|addon| addon.features}.flatten
    end

    def add_ons_changed?
      !(@existing_add_ons & account_add_ons == @existing_add_ons and 
            account_add_ons & @existing_add_ons == account_add_ons)
    end

    def plan_changed?
      new_plan.subscription_plan_id != old_plan.subscription_plan_id
    end

end