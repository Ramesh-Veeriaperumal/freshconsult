class Fdadmin::SubscriptionPlansController < Fdadmin::DevopsMainController
  around_filter :run_on_slave

  def all_plans
    result = SubscriptionPlan.ordered_plans
    render json: { plans: result }
  end
end
