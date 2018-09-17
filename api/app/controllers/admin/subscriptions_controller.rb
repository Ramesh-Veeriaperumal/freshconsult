class Admin::SubscriptionsController < ApiApplicationController
  include SubscriptionsHelper
  include HelperConcern
  decorate_views(decorate_objects: [:plans])
  before_filter :validate_query_params, only: [:plans]

  ADMIN_SUBSCRIPTION_CONSTANTS_CLASS = 'AdminSubscriptionConstants'.freeze

  def plans
    @items = SubscriptionPlan.cached_current_plans
    response.api_root_key = :plans
  end

private

  def load_object
    @item = current_account.subscription
  end

  def decorator_options
    options = {}
    if action_name.to_sym == :plans
      currency = params[:currency].blank? ? current_account.subscription.currency 
        : Subscription::Currency.currency_by_name(params[:currency]).first
      options[:currency] = currency.name
      options[:plans_to_agent_cost] = 
        Billing::Subscription.current_plans_costs_per_agent_from_cache(currency)
    end
    super options
  end

  def constants_class
    ADMIN_SUBSCRIPTION_CONSTANTS_CLASS
  end
end
