module SubscriptionsHelper 
  include Subscription::Currencies::Constants
  include ActionView::Helpers::NumberHelper

  PLANS_FEATURES = PlanFeaturesConfig

  OMNI_FEATURES = {
    "sproutomni_channel_option" => ["sprout_omni"],
    "blossomomni_channel_option" => ["blossom_omni"],
    "gardenomni_channel_option" => ["chat_faq", "chat_message", "ivr", "masking_recording"],
    "estateomni_channel_option" => ["chatbots", "inapp_chat", "smart_calls", "barging_monitoring"],
    "forestomni_channel_option" => ["co_browsing", "multilingual_chat", "holiday_routing"]
  }

  PLANS_FEATURES_LOSS = {
    "blossom" => ["time_event_automation_desc", "sla_reminders" , "custom_fields_desc", "multiple_mailbox_desc"],
    "garden" => ["multiple_sla_business_desc", "forums_desc"],
    "estate" => ["multiple_products_desc", "portal_customization_desc", "custom_ssl_desc", "enterprise_reports_desc"],
    "forest" => ["whitelisted_ip_desc", "custom_mailbox_desc", "advanced_phone_desc"],

    "blossom jan 17" => ["time_event_automation_desc", "sla_reminders", "custom_fields_desc", "multiple_mailbox_desc", "adv_social_desc"],
    "garden jan 17" => ["multilingual_kbase_desc", "live_chat_desc", "forums_desc", "custom_survey_desc", "ticket_templates"],
    "estate jan 17" => ["multiple_products_desc", "multiple_sla_business_desc", "portal_customization_desc", "custom_ssl_desc", "enterprise_reports_desc", "custom_dashboard"],
    "forest jan 17" => ["whitelisted_ip_desc", "skill_based_assignment_desc", "custom_mailbox_desc", "advanced_phone_desc"]
  }


  PLANS_FEATURES_LOSS_2019 = {
    "blossom" => ["time_event_automation_desc", "sla_reminders", "agent_group_pf_report", "agent_scope_desc", "business_hours_desc", "sla_desc", "custom_fields_desc", "multiple_mailbox_desc", "forums_desc", "gamification_desc"],
    "garden" => ["agent_group_pf_report", "sla_reminders_desc", "multiple_sla_business_desc", "forums_desc", "multiple_languages_desc", "multiple_products_desc", "multiple_timezones_desc"],
    "estate" => ["multiple_products_desc", "portal_customization_desc", "custom_ssl_desc", "enterprise_reports_desc", "multiple_sla_business_desc"],
    "forest" => ["whitelisted_ip_desc", "advanced_phone_desc", "ip_restriction"],

    "blossom jan 17" => ["time_event_automation_desc", "sla_reminders", "agent_performance_report_desc", "agent_scope_desc", "business_hours_desc", "custom_fields_desc", "multiple_mailbox_desc", "adv_social_desc", "custom_apps_desc"],
    "garden jan 17" => ["multilingual_kbase_desc", "live_chat_desc", "forums_desc", "custom_survey_desc", "parent_child_desc"],
    "estate jan 17" => ["multiple_products_desc", "multiple_sla_business_desc", "portal_customization_desc", "custom_ssl_desc", "enterprise_reports_desc", "custom_dashboard_desc"],
    "forest jan 17" => ["whitelisted_ip_desc", "skill_based_assignment_desc", "sandbox_desc"],

    "blossom jan 19" => ["multiple_mailboxes_desc", "app_gallery_desc",
      "time_event_automation_desc", "custom_domain_desc",
      "helpdesk_report_desc", "custom_ticket_fields_and_views_desc",
      "agent_collision_desc"],
    "garden jan 19" => ["multilingual_kbase_desc", "dynamic_email_alert_desc", "ticket_templates_desc",
      "sla_reminders_desc", "forums_desc", "agent_performance_report_desc", "satisfaction_survey_desc",
      "scheduled_reports_desc", "custom_surveys_desc", "custom_apps_desc", "timesheets_desc", "chat_faq", "chat_message", "ivr", "masking_recording", "customer_journey_desc"],
    "estate jan 19" => ["multiple_products_desc", "multiple_sla_business_desc", "portal_customization_desc",
                        "custom_ssl_desc", "auto_ticket_assignment_desc", "enterprise_reports_desc", "custom_dashboard_desc", "chatbots", "inapp_chat", "smart_calls", "barging_monitoring", "omni_analytics", "fsm_desc", "custom_translations"],
    "garden omni jan 19" => ["multilingual_kbase_desc", "dynamic_email_alert_desc",
      "sla_reminders_desc", "forums_desc", "agent_performance_report_desc",
      "scheduled_reports_desc", "custom_surveys_desc", "custom_apps_desc", "timesheets_desc", "co_browsing", "customer_journey_desc"],
    "estate omni jan 19" => ["multiple_products_desc", "multiple_sla_business_desc", "portal_customization_desc",
      "custom_ssl_desc", "auto_ticket_assignment_desc", "enterprise_reports_desc", "custom_dashboard_desc"],   
    "forest jan 19" => ["skill_based_assignment_desc", "sandbox_desc", "whitelisted_ip_desc", "co_browsing", "multilingual_chat", "omni_routing"]
  }

  PLAN_RANKING = {
    "free" => 0,
    
    "basic" => 0,
    "pro" => 0,
    "premium" => 0,
    
    "sprout classic" => 0,
    "blossom classic" => 0,
    "garden classic" => 0,
    "estate classic" => 0,
    
    "sprout" => 1,
    "blossom" => 2,
    "garden" => 3,
    "estate" => 4,
    "forest" => 5,

    "sprout jan 17" => 1,
    "blossom jan 17" => 2,
    "garden jan 17" => 3,
    "estate jan 17" => 4,
    "forest jan 17" => 5,

    "sprout jan 19" => 1,
    "blossom jan 19" => 2,
    "garden jan 19" => 3,
    "estate jan 19" => 4,
    "forest jan 19" => 5,

    "garden omni jan 19" => 3,
    'estate omni jan 19' => 4,

    'sprout jan 20' => 1,
    'blossom jan 20' => 2,
    'garden jan 20' => 3,
    'estate jan 20' => 4,
    'forest jan 20' => 5,

    'garden omni jan 20' => 3,
    'estate omni jan 20' => 4,
    'forest omni jan 20' => 5
  }

  EQUAL_PLAN_HASH = {
    "sprout jan 17" => {:type_flag => 0, :features => ["time_event_automation_desc", "sla_reminders" , "shared_ticket_views_desc", "custom_fields_desc", "custom_ticket_views_desc", "cname_dkim_desc", "multiple_mailbox_desc"]},
    "blossom jan 17" => {:type_flag => 0, :features => ["forums_desc"]},
    "garden jan 17" => {:type_flag => 0, :features => ["multiple_products_desc", "multiple_sla_business_desc"]},
    "estate jan 17" => {:type_flag => 2, :features => []},
    "forest jan 17" => {:type_flag => 2, :features => []},

    "sprout jan 19" => {:type_flag => 0, :features => ["scenario_automations_desc", "custom_tabel_view_desc", "sla_desc", "business_hours_desc", "agent_scope_desc", "agent_group_pf_report"]},
    "blossom jan 19" => {:type_flag => 0, :features => ["sla_reminders_desc", "agent_group_pf_report", "timesheets_desc", "canned_forms_desc", "custom_apps_desc", "customer_360_desc"]},
    "garden jan 19" => {:type_flag => 0, :features => ["parent_child_desc"]},
    "estate jan 19" => {:type_flag => 2, :features => []},
    "garden omni jan 19" => {:type_flag => 0, :features => ["parent_child_desc"]},
    "estate omni jan 19" => {:type_flag => 2, :features => ["scenario_automations_desc"]},
    'forest jan 19' => { type_flag: 2, features: [] }
  }

  NEW_SPROUT = ['Sprout Jan 17', 'Sprout Jan 19', 'Sprout Jan 20'].freeze

  OMNI_PLANS_SERIES = SubscriptionPlan::JAN_2019_PLAN_NAMES.reject { |name| SubscriptionPlan::OMNI_TO_BASIC_PLAN_MAP.key(name) }
  NON_OMNI_PLANS_SERIES = SubscriptionPlan::JAN_2019_PLAN_NAMES.reject { |name| SubscriptionPlan::BASIC_PLAN_TO_OMNI_MAP.key(name) }

  def get_payment_string(period,amount)
    amount = format_amount(amount, current_account.currency_name)
    if period == SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual]
      return sanitize(t('amount_billed_annually', :amount => amount, tax_string: tax_string))
    end
    sanitize(t('amount_billed_per_month',:amount => amount,:period => SubscriptionPlan::BILLING_CYCLE_NAMES_BY_KEY[period], tax_string: tax_string))
  end

  def tax_string
    tax_inclusive?(current_account.subscription) ? "<span class='tax-text'> " + t('tax_inclusion') + '</span>.' : '.'
  end

  def get_amount_string(period,amount)
    if period == SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual]
      return t('amount_for_annual', :amount => amount ).html_safe 
    end
    return  t('amount_per_month',{:amount => amount,:period => SubscriptionPlan::BILLING_CYCLE_NAMES_BY_KEY[period]}).html_safe
  end

  def open_html_tag
    html_conditions = [ ["lt IE 7", "ie6"],
                        ["IE 7", "ie7"],
                        ["IE 8", "ie8"],
                        ["IE 9", "ie9"],
                        ["IE 10", "ie10"],
                        ["(gt IE 10)|!(IE)", "", true]]

    date_format = (AccountConstants::DATEFORMATS[current_account.account_additional_settings.date_format] if current_account.account_additional_settings) || :non_us

    html_conditions.map { |h|
      %(
        <!--[if #{h[0]}]>#{h[2] ? '<!-->' : ''}<html class="no-js #{h[1]}" lang="#{
          current_portal.language }" dir="#{current_direction?}" data-date-format="#{date_format}">#{h[2] ? '<!--' : ''}<![endif]-->)
    }.to_s.html_safe
  end

  def current_freshfone_balance(freshfone_credit)
    balance = (freshfone_credit) ? freshfone_credit.available_credit : 0
    number_to_currency(balance) 
  end

  def recharge_options
    cost_options = []
    credit_price = current_account.subscription.retrieve_addon_price(:freshfone)
    (Freshfone::Credit::RECHARGE_OPTIONS).each{ |credit|
      cost_options << [ format_amount((credit * credit_price), current_account.currency_name), credit ]
    }
    cost_options
  end

  def default_freshfone_credit(freshfone_credit)
    return Freshfone::Credit::DEFAULT if freshfone_credit.new_record?
    current_credit = freshfone_credit.credit
    return current_credit.to_i if Freshfone::Credit::RECHARGE_OPTIONS.include?(current_credit)
    Freshfone::Credit::DEFAULT
  end

  def default_freshfone_auto_recharge(freshfone_credit)
    return Freshfone::Credit::DEFAULT if freshfone_credit.new_record?
    recharge_quantity = freshfone_credit.recharge_quantity
    return recharge_quantity if Freshfone::Credit::RECHARGE_OPTIONS.include?(recharge_quantity)
    Freshfone::Credit::DEFAULT
  end

  def multicurrency_followup_amount
    (@freshfone_credit && @freshfone_credit.last_purchased_credit.nonzero?) ? 
      @freshfone_credit.last_purchased_credit : Freshfone::Credit::DEFAULT
  end

  def fetch_recharge_amount
    credit_price = current_account.subscription.retrieve_addon_price(:freshfone)
    recharge_price = current_account.freshfone_credit.recharge_quantity * credit_price
    format_amount(recharge_price, current_account.currency_name)
  end

  def fetch_plan_amount(plan)
    currency = current_account.currency_name
    amount = plan.pricing(currency)
    format_amount(amount, currency)
  end

  def cost_per_agent(plan_name, period, currency)
    billing_subscription = Billing::Subscription.new
    if period.nil?
      period = SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual]
    end
    plan_info = billing_subscription.retrieve_plan(plan_name, period)
    amount = (plan_info.plan.price/plan_info.plan.period)/100
    format_amount(amount, currency)
  end

  def cost_per_field_agent(currency)
    amount = current_account.subscription.retrieve_addon_price(:field_service_management)
    format_amount(amount, currency)
  end

  def format_amount(amount, currency)    
    number_to_currency(amount, :unit => CURRENCY_UNITS[currency], :separator => ".", 
      :delimiter => ",", :format => "%u%n", :precision => 0)
  end

  def fetch_currency_unit
    CURRENCY_UNITS[current_account.currency_name]
  end

  def fetch_currencies
    options_for_select(SUPPORTED_CURRENCIES, :selected => current_account.currency_name)
  end

  def default_currency?
    current_account.currency_name.eql?(DEFAULT_CURRENCY)
  end

  def plan_button(plan, button_label, button_classes, free_plan_flag, add_freshdialog,
    title = "", data_submit_label = "", data_close_label = "", data_classes = "",
    data_submit_loading = t('please_wait'), billing_cycle = SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual])
    output = []
    output << %(<button data-plan="#{ plan.name.parameterize.underscore }" 
                  data-plan-id="#{ plan.id }" 
                  class="#{button_classes}" 
                  id="#{ plan.name.parameterize.underscore }_button" 
                  data-current-plan="false"
                  data-heap-id="choose-plan"
                  data-free-plan="#{ free_plan_flag }"
                  data-billing-cycle="#{ billing_cycle }")
    if add_freshdialog
      output << %(data-target="#confirm-message-#{plan.id}"  
                    title="#{ title }"
                    data-classes = "#{ data_classes }"
                    data-submit-label="#{ data_submit_label }"
                    data-close-label="#{ data_close_label }"
                    data-submit-loading="#{ data_submit_loading }"
                    rel="freshdialog" )
    end
    output << %( > #{button_label} </button>)
    output.join("").html_safe
  end

  def freshfone_allowed?
    feature?(:freshfone) && !freshfone_trial_states?
  end

  def fsm_supported_plan?(plan)
    # Adding temporarily and will be removed once FSM is supported in all Garden and Blossom plans
    return false if fsm_supported_for_garden?(plan.name) || fsm_supported_for_blossom?(plan.name)

    features = PLANS_FEATURES["#{plan.name.downcase}"]
    current_account.disable_old_ui_enabled? && (features || []).include?('fsm_option')
  end

  def fsm_supported_for_garden?(plan_name)
    garden_plan = ['Garden', 'Garden Jan 17', 'Garden Jan 19', 'Garden Omni Jan 19', 'Garden Jan 20', 'Garden Omni Jan 20']
    garden_plan.include?(plan_name) && !current_account.fsm_for_garden_plan_enabled?
  end

  def fsm_supported_for_blossom?(plan_name)
    blossom_plan = ['Blossom', 'Blossom Jan 17', 'Blossom Jan 19', 'Blossom Jan 20']
    blossom_plan.include?(plan_name) && !current_account.fsm_for_blossom_plan_enabled?
  end

  def previous_plan?(plan)
    SubscriptionPlan.previous_plans.include?(plan)
  end

  def new_sprout?(plan_name)
    NEW_SPROUT.include?(plan_name)
  end

  def get_current_plans(is_old_plan)
    if is_old_plan
      SubscriptionPlan.previous_plans.pluck(:name)
    else
      SubscriptionPlan.current.pluck(:name)
    end
  end

  def get_plan_names(account_subscription_plan)
    plan_name = account_subscription_plan.name
    if SubscriptionPlan::PLAN_NAMES_BEFORE_2017_AND_NOT_GRAND_PARENT.include?(plan_name)
      SubscriptionPlan::PLAN_NAMES_BEFORE_2017_AND_NOT_GRAND_PARENT
    elsif SubscriptionPlan::JAN_2017_PLAN_NAMES.include?(plan_name)
      SubscriptionPlan::JAN_2017_PLAN_NAMES
    elsif SubscriptionPlan::BASIC_PLAN_TO_OMNI_MAP.key(plan_name).present?
      OMNI_PLANS_SERIES
    else
      NON_OMNI_PLANS_SERIES
    end
  end

  def losing_features(plan_name, account)
    if account.new_2020_pricing_enabled?
      PLANS_FEATURES_LOSS_2019["#{plan_name.downcase}"]
    else
      PLANS_FEATURES_LOSS_2019["#{plan_name.downcase}"]
    end
  end

  def tax_inclusive?(subscription)
    subscription.additional_info[:amount_with_tax].present? && subscription.additional_info[:amount_with_tax] != subscription.amount ? true : false
  end
  def show_billing_info
    !@offline_subscription && !@reseller_paid_account
  end
end
