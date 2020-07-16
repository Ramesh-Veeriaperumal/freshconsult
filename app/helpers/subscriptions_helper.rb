module SubscriptionsHelper 
  include Subscription::Currencies::Constants
  include ActionView::Helpers::NumberHelper

  PLANS_FEATURES = PlanFeaturesConfig
  AGENTS = :agents
  FIELD_TECHNICIANS = :'field technicians'
  PRODUCTS = :products

  OMNI_FEATURES = {
    "sproutomni_channel_option" => ["sprout_omni"],
    "blossomomni_channel_option" => ["blossom_omni"],
    'gardenomni_channel_option_basic' => ['blossom_omni'],
    "gardenomni_channel_option" => ["chat_faq", "chat_message", "ivr", "masking_recording"],
    "estateomni_channel_option" => ["holiday_routing", "multilingual_chat", "apple_business_chat", "smart_calls", "barging_monitoring"],
    "forestomni_channel_option" => ["omni_routing", "co_browsing", "custom_bots_chat", "abandoned_call_metrics", "service_level_monitoring", "abandoned_call_reports", "service_level_report", "cre_metrics"]
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

    'estate omni jan 20' => 4,
    'forest omni jan 20' => 5
  }

  IMPORTANT_OMNI_FEATURES = {
    'estate omni jan 20' => [
      :multilingual_chat,
      :holiday_routing,
      :apple_business_chat
    ],
    'forest omni jan 20' => [
      :omni_routing,
      :custom_bots_chat,
      :abandoned_call_metrics,
      :service_level_monitoring,
      :abandoned_call_reports,
      :service_level_report,
      :cre_metrics
    ]
  }


  NEW_SPROUT = ['Sprout Jan 17', 'Sprout Jan 19', 'Sprout Jan 20'].freeze

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
    amount = current_account.omni_bundle_account? ? plan.omni_pricing(currency) : plan.pricing(currency)
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
    features = PLANS_FEATURES["#{plan.name.downcase}"]
    Account.current.disable_old_ui_enabled? && (features || []).include?('fsm_option')
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

  def tax_inclusive?(subscription)
    subscription.additional_info[:amount_with_tax].present? && subscription.additional_info[:amount_with_tax] != subscription.amount ? true : false
  end
  def show_billing_info
    !@offline_subscription && !@reseller_paid_account
  end

  def construct_subscription_error_msgs(errors)
    error_type = errors.map(&:keys).flatten!
    entities = errors.map(&:values).to_sentence(last_word_connector: I18n.t('subscription.error.word_connector'))
    second_part = if error_type.include?(AGENTS) || error_type.include?(FIELD_TECHNICIANS)
                    error_type.include?(PRODUCTS) ? I18n.t('subscription.error.agents_and_product') : I18n.t('subscription.error.only_agents')
                  elsif error_type.include?(PRODUCTS)
                    I18n.t('subscription.error.only_product')
                  end
    action_sentence = I18n.t('subscription.error.action_sentence', exceeded_agent_and_product_count: error_type.to_sentence(last_word_connector: I18n.t('subscription.error.word_connector')))
    I18n.t('subscription.error.agents_and_product_limit_exceeded', entities: entities) << second_part << action_sentence
  end

  def get_omni_features(plan_name)
    IMPORTANT_OMNI_FEATURES["#{plan_name}"] || []
  end
end
