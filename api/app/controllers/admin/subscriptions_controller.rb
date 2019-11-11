class Admin::SubscriptionsController < ApiApplicationController
  include SubscriptionsHelper
  include HelperConcern
  decorate_views(decorate_objects: [:plans], decorate_object: [:estimate])
  before_filter :validate_query_params, only: [:plans, :estimate]
  before_filter -> { validate_delegator(nil, cname_params) }, only: [:update]

  ADMIN_SUBSCRIPTION_CONSTANTS_CLASS = 'AdminSubscriptionConstants'.freeze

  def plans
    @items = SubscriptionPlan.cached_current_plans
    response.api_root_key = :plans
  end

  def update
    if @item.update_subscription(cname_params)
      @item = @item.present_subscription if @item.subscription_downgrade?
      render(action: :show)
    else
      render_custom_errors
    end
  end

  def estimate
    return unless validate_delegator(nil, params)
    @item.agent_limit = fetch_agent_limit
    @item.plan_id = params[:plan_id] if params[:plan_id].present?
    @item.renewal_period = params[:renewal_period]
    response.api_root_key = :estimate
  end

  private

    def validate_params
      validate_body_params
    end

    def load_object
      @item = current_account.subscription
    end

    def fetch_agent_limit
      @item.new_sprout? && @item.agent_limit == params[:agent_seats].to_i && @item.agent_limit == @item.free_agents ? current_account.full_time_support_agents.count : params[:agent_seats]
    end

    def decorator_options
      options = {}
      if action_name.to_sym == :plans
        currency = params[:currency].blank? ? current_account.subscription.currency
          : Subscription::Currency.currency_by_name(params[:currency]).first
        options[:currency] = currency.name
        options[:plans_to_agent_cost] =
          Billing::Subscription.current_plans_costs_per_agent_from_cache(currency)
      elsif action_name.to_sym == :estimate
        options.merge!(fetch_estimate_details_from_chargebee)
      end
      super options
    end

    def fetch_estimate_details_from_chargebee
      {
        immediate_subscription_estimate: @item.fetch_immediate_estimate,
        future_subscription_estimate: @item.fetch_subscription_estimate
      }
    end

    def constants_class
      ADMIN_SUBSCRIPTION_CONSTANTS_CLASS
    end
end
