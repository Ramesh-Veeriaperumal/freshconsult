class Account < ActiveRecord::Base

  LP_FEATURES   = [:link_tickets, :select_all, :round_robin_capping, :suggest_tickets, :customer_sentiment_ui, :dkim]
  DB_FEATURES   = [:custom_survey, :requester_widget, :collaboration]
  BOTH_FEATURES = [:shared_ownership]
  BITMAP_FEATURES = [:split_tickets, :add_watcher, :traffic_cop, :custom_ticket_views, :supervisor, :create_observer, :sla_management, 
    :email_commands, :assume_identity, :rebranding, :custom_apps, :custom_ticket_fields, :custom_company_fields, 
    :custom_contact_fields, :occasional_agent, :allow_auto_suggest_solutions, :basic_twitter, :basic_facebook, :branding, :advanced_dkim, :basic_dkim]
    
  LP_FEATURES.each do |item|
    define_method "#{item.to_s}_enabled?" do
      launched?(item)   
    end
  end

  DB_FEATURES.each do |item|
    define_method "#{item.to_s}_enabled?" do
      features?(item)   
    end
  end

  BOTH_FEATURES.each do |item|
    define_method "#{item.to_s}_enabled?" do
      has_both_feature?(item)
    end
  end

  BITMAP_FEATURES.each do |item|
    define_method "#{item.to_s}_enabled?" do
      has_feature?(item)
    end
  end

  def has_both_feature? f
    features?(f) && launched?(f)
  end

  def restricted_helpdesk?
    features?(:restricted_helpdesk) && helpdesk_restriction_enabled?
  end

  def tag_based_article_search_enabled?
    ismember?(TAG_BASED_ARTICLE_SEARCH, self.id)
  end

  def classic_reports_enabled?
    ismember?(CLASSIC_REPORTS_ENABLED, self.id)
  end

  def old_reports_enabled?
    ismember?(OLD_REPORTS_ENABLED, self.id)
  end

  def plugs_enabled_in_new_ticket?
    ismember?(PLUGS_IN_NEW_TICKET,self.id)
  end

  def pass_through_enabled?
    pass_through_enabled
  end

  def any_survey_feature_enabled?
    survey_enabled? || default_survey_enabled? || custom_survey_enabled?
  end

  def any_survey_feature_enabled_and_active?
    new_survey_enabled? ? active_custom_survey_from_cache.present? :
      features?(:surveys, :survey_links)
  end

  def survey_enabled?
    features?(:surveys)
  end

  def new_survey_enabled?
    default_survey_enabled? || custom_survey_enabled?
  end

  def default_survey_enabled?
    features?(:default_survey) && !custom_survey_enabled?
  end

  def count_es_enabled?
    (launched?(:es_count_reads) || launched?(:list_page_new_cluster)) && features?(:countv2_reads)
  end

  def customer_sentiment_enabled?
    Rails.logger.info "customer_sentiment : #{launched?(:customer_sentiment)}"
    launched?(:customer_sentiment)
  end

  def freshfone_enabled?
    features?(:freshfone) and freshfone_account.present?
  end

  def freshchat_enabled?
    features?(:chat) and !chat_setting.site_id.blank?
  end

  def freshchat_routing_enabled?
    freshchat_enabled? and features?(:chat_routing)
  end

  def supervisor_feature_launched?
    features?(:freshfone_call_monitoring) || features?(:agent_conference)
  end

  def compose_email_enabled?
    !features?(:compose_email) || ismember?(COMPOSE_EMAIL_ENABLED, self.id)
  end

  def helpdesk_restriction_enabled?
     features?(:helpdesk_restriction_toggle) || launched?(:restricted_helpdesk)
  end

  def dashboard_disabled?
    ismember?(DASHBOARD_DISABLED, self.id)
  end

  def dashboardv2_enabled?
   launched?(:admin_dashboard) || launched?(:supervisor_dashboard) || launched?(:agent_dashboard)
  end

  def restricted_compose_enabled?
    ismember?(RESTRICTED_COMPOSE, self.id)
  end
 
  def hide_agent_metrics_feature?
    features?(:euc_hide_agent_metrics)
  end
  
  def new_pricing_launched?
    on_new_plan? || redis_key_exists?(NEW_SIGNUP_ENABLED)
  end

  def advance_facebook_enabled?
    features?(:facebook)
  end

  def advanced_twitter?
    features? :twitter
  end

  def on_new_plan?
    @on_new_plan ||= [:sprout_jan_17,:blossom_jan_17,:garden_jan_17,:estate_jan_17,:forest_jan_17].include?(plan_name)
  end

  def tags_filter_reporting_enabled?    
    features?(:tags_filter_reporting)   
  end

  def selectable_features_list
    SELECTABLE_FEATURES_DATA || {}
  end
end