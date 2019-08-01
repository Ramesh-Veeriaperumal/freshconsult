class Account < ActiveRecord::Base

  def create_fluffy_account
    Fluffy::ApiWrapper.create(full_domain, api_limit)
  end

  def destroy_fluffy_account
    fluffy_account = Fluffy::ApiWrapper.new(full_domain)
    fluffy_account.destroy
  end

  def update_fluffy_account(limit = api_limit)
    fluffy_account = Fluffy::ApiWrapper.new(full_domain)
    fluffy_account.update(limit)
  end

  def enable_fluffy
    launch(:fluffy) if create_fluffy_account
  end

  def disable_fluffy
    rollback(:fluffy) if destroy_fluffy_account
  end

  def api_limit
    get_api_limit_from_redis(id, subscription.plan_id)
  end

end