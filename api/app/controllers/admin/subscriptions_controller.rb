class Admin::SubscriptionsController < ApiApplicationController
  include HelperConcern
  decorate_views(decorate_objects: [:plans], decorate_object: [:estimate, :update_payment, :fetch_plan])
  before_filter :validate_query_params, only: [:plans, :estimate, :estimate_feature_loss, :fetch_plan]
  before_filter -> { validate_delegator(nil, cname_params) }, only: [:update]

  ADMIN_SUBSCRIPTION_CONSTANTS_CLASS = 'AdminSubscriptionConstants'.freeze

  def plans
    @items = SubscriptionPlan.cached_current_plans
    response.api_root_key = :plans
  end

  def fetch_plan
    response.api_root_key = :plans
    head 404 if @item.nil?
  end

  def update
    @item.switch_currency(cname_params[:currency]) if currency_switched?
    if @item.update_subscription(cname_params)
      @item = @item.present_subscription if @item.subscription_downgrade?
      render(action: :show)
    else
      render_custom_errors
    end
  end

  def estimate
    return unless validate_delegator(nil, params)
    @coupon = @item.coupon
    @item.set_billing_params(params[:currency]) if params[:currency].present?
    @item.agent_limit = fetch_agent_limit
    @item.plan_id = params[:plan_id] if params[:plan_id].present?
    @item.renewal_period = params[:renewal_period]
    response.api_root_key = :estimate
  end

  def update_payment
    if @item.add_card_to_billing && @item.activate_subscription
      response.api_root_key = :subscription
      render(action: :show)
    else
      head 400
    end
  end

  def estimate_feature_loss
    plan_id = params[:plan_id].to_i
    @items = current_account.subscription.losing_features(plan_id)
    response.api_root_key = :estimate_feature_loss
  end

  private

    def currency_switched?
      cname_params[:currency].present? && @item.currency_name != cname_params[:currency]
    end

    def sanitize_params
      if @item.new_sprout?
        @item.agent_limit = cname_params[:agent_seats].present? && cname_params[:agent_seats] != @item.free_agents ? cname_params[:agent_seats] : current_account.full_time_support_agents.count
      end
    end

    def validate_params
      validate_body_params
    end

    def validate_url_params
      @validation_klass = 'AdminSubscriptionValidation'
      validate_query_params
    end

    def load_object
      @item = if action_name.to_sym == :fetch_plan
                SubscriptionPlan.subscription_plans_from_cache.find { |plan| plan.id == params[:id].to_i }
              else
                current_account.subscription
              end
    end

    def fetch_agent_limit
      @item.new_sprout? && @item.agent_limit == params[:agent_seats].to_i && @item.agent_limit == @item.free_agents ? current_account.full_time_support_agents.count : params[:agent_seats]
    end

    def sideload_options
      @validator.include_array
    end

    def decorator_options
      options = {}
      if show? && sideload_options.present?
        options[:update_payment_site] = @item.fetch_update_payment_site if sideload_options.include?('update_payment_site')
      elsif [:plans, :fetch_plan].include?(action_name.to_sym)
        currency = params[:currency].blank? ? current_account.subscription.currency
          : Subscription::Currency.currency_by_name(params[:currency]).first
        options[:currency] = currency.name
        options[:plans_to_agent_cost] =
          Billing::Subscription.all_plans_costs_per_agent_from_cache(currency)
      elsif action_name.to_sym == :estimate
        options.merge!(fetch_estimate_details_from_chargebee)
      end
      super options
    end

    def fetch_estimate_details_from_chargebee
      {
        immediate_subscription_estimate: @item.fetch_immediate_estimate,
        future_subscription_estimate: @item.fetch_subscription_estimate(@coupon)
      }
    end

    def constants_class
      ADMIN_SUBSCRIPTION_CONSTANTS_CLASS
    end
end
