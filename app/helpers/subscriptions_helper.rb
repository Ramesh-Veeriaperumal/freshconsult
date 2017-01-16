module SubscriptionsHelper 
  include Subscription::Currencies::Constants

  PLANS_FEATURES = {
    "sprout" => [ "email_ticketing", "feedback_widget" ,"knowledge_base", "automations", "phone_integration", "mobile_apps", "integrations" ],
    "blossom" => [ "everything_in_sprout", "multiple_mailboxes", "custom_domain", "social_support", "satisfaction_survey", "forums", "gamification" ],
    "garden" => [ "everything_in_blossom", "chat", "multiple_languages", "multiple_products", "multiple_timezones", "css_customization" ],
    "estate" => [ "everything_in_garden", "agent_collision", "custom_roles", "custom_ssl", "enterprise_reports", "portal_customization" ],
    "forest" => [ "everything_in_estate", "custom_mailbox", "ip_restriction" ],

    "sprout jan 17" => [ "email_ticketing", "ticket_dispatch_automation" ,"knowledge_base", "app_gallery", "basic_phone" ],
    "blossom jan 17" => [ "everything_in_sprout", "multiple_mailboxes", "time_event_automation", "sla_reminders", "custom_domain", "satisfaction_survey",
      "helpdesk_report", "custom_ticket_fields_and_views"],
    "garden jan 17" => [ "everything_in_blossom", "m_k_base", "dynamic_email_alert", "chat", "forums", "scheduled_reports",
       "ticket_templates", "custom_surveys"],
    "estate jan 17" => [ "everything_in_garden", "multiple_products", "multiple_sla", "portal_customization", "custom_roles", "agent_collision", "auto_ticket_assignment",
       "role_dashboard", "enterprise_reports"],
    "forest jan 17" => [ "everything_in_estate", "ip_whitelisting", "custom_mailbox", "advanced_phone_integration",  "custom_data_center" ]
  }

  PLANS_FEATURES_LOSS = {
    "blossom" => ["time_event_automation_desc", "sla_reminders" , "custom_fields_desc", "multiple_mailbox_desc"],
    "garden" => ["multiple_sla_business_desc", "forums_desc"],
    "estate" => ["multiple_products_desc", "portal_customization_desc", "custom_ssl_desc", "enterprise_reports_desc"],
    "forest" => ["whitelisted_ip_desc", "custom_mailbox_desc", "advanced_phone_desc"],

    "blossom jan 17" => ["time_event_automation_desc", "sla_reminders", "custom_fields_desc", "multiple_mailbox_desc", "adv_social_desc"],
    "garden jan 17" => ["multilingual_kbase_desc", "live_chat_desc", "forums_desc", "custom_survey_desc", "ticket_templates"],
    "estate jan 17" => ["multiple_products_desc", "multiple_sla_business_desc", "portal_customization_desc", "custom_ssl_desc", "enterprise_reports_desc"],
    "forest jan 17" => ["whitelisted_ip_desc", "custom_mailbox_desc", "advanced_phone_desc"]
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
    "forest jan 17" => 5
  }

  EQUAL_PLAN_HASH = {
    "sprout jan 17" => {:type_flag => 0, :features => ["time_event_automation_desc", "sla_reminders" , "shared_ticket_views_desc", "custom_fields_desc", "custom_ticket_views_desc", "cname_dkim_desc", "multiple_mailbox_desc"]},
    "blossom jan 17" => {:type_flag => 0, :features => ["forums_desc"]},
    "garden jan 17" => {:type_flag => 0, :features => ["multiple_products_desc", "multiple_sla_business_desc"]},
    "estate jan 17" => {:type_flag => 2, :features => []},
    "forest jan 17" => {:type_flag => 2, :features => []}
  }

  NEW_SPROUT = "Sprout Jan 17"

  def get_payment_string(period,amount)
    amount = format_amount(amount, current_account.currency_name)
    if period == SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual]
        return t('amount_billed_annually', :amount => amount ).html_safe 
    end
    return  t('amount_billed_per_month',{:amount => amount,:period => SubscriptionPlan::BILLING_CYCLE_NAMES_BY_KEY[period]}).html_safe
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

  def cost_per_agent(plan_name, period=1, currency)
    billing_subscription = Billing::Subscription.new
    period = 1 if period.nil?
    plan_info = billing_subscription.retrieve_plan(plan_name, period)
    amount = (plan_info.plan.price/plan_info.plan.period)/100
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
    options_for_select(BILLING_CURRENCIES, :selected => current_account.currency_name)
  end

  def default_currency?
    current_account.currency_name.eql?(DEFAULT_CURRENCY)
  end

  def plan_button(plan, button_label, button_classes, free_plan_flag, add_freshdialog, title = "", data_submit_label = "", data_close_label = "", data_classes = "", data_submit_loading = t('please_wait'))
    output = []
    output << %(<button data-plan="#{ plan.name.parameterize.underscore }" 
                  data-plan-id="#{ plan.id }" 
                  class="#{button_classes}" 
                  id="#{ plan.name.parameterize.underscore }_button" 
                  data-current-plan="false"
                  data-free-plan="#{ free_plan_flag }" )
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

  def previous_plan?(plan)
    SubscriptionPlan.previous_plans.include?(plan)
  end
  
  def new_sprout?(plan_name)
    plan_name == NEW_SPROUT
  end

  def get_current_plans(is_old_plan)
    if is_old_plan
      SubscriptionPlan.previous_plans.pluck(:name)
    else
      SubscriptionPlan.current.pluck(:name)
    end
  end

 end
