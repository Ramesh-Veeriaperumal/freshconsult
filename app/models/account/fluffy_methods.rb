class Account < ActiveRecord::Base
  API_MIN_LIMIT = 400
  def create_fluffy_account(limit=nil, granularity = Fluffy::ApiWrapper::HOUR_GRANULARITY)
    limit ||= (granularity == Fluffy::ApiWrapper::MINUTE_GRANULARITY ? api_min_limit : api_limit)
    Fluffy::ApiWrapper.create(full_domain, limit, granularity)
  end

  def destroy_fluffy_account(domain = full_domain)
    fluffy_account = Fluffy::ApiWrapper.new(domain)
    fluffy_account.destroy
  end

  def update_fluffy_account(limit = nil, granularity = Fluffy::ApiWrapper::HOUR_GRANULARITY)
    return false unless fluffy_integration_enabled?
    fluffy_account = Fluffy::ApiWrapper.new(full_domain)
    if granularity == Fluffy::ApiWrapper::MINUTE_GRANULARITY
      if fluffy_account.update(limit || api_min_limit, granularity) && fluffy_enabled?
        rollback(:fluffy)
        launch(:fluffy_min_level)
        Rails.logger.info "FLUFFY limit update from hour to minute :: #{self.id} :: #{limit || api_min_limit}"
      end
    else
      if fluffy_account.update(limit || api_limit, granularity) && fluffy_min_level_enabled?
        rollback(:fluffy_min_level)
        launch(:fluffy)
        Rails.logger.info "FLUFFY limit update :: from minute to hour :: #{self.id} :: #{limit || api_limit}"
      end
    end
  end

  def change_fluffy_api_limit(limit = nil)
    if fluffy_enabled?
      update_fluffy_account(limit)
    elsif fluffy_min_level_enabled?
      update_fluffy_account(limit, Fluffy::ApiWrapper::MINUTE_GRANULARITY)
    end
  end

  def current_fluffy_limit(domain = full_domain)
    fluffy_account = Fluffy::ApiWrapper.find_by_domain(domain)
    fluffy_account if fluffy_account.present? && fluffy_account.is_a?(Fluffy::Account)
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

  def api_min_limit
    (get_api_min_limit_from_redis(subscription.plan_id) || API_MIN_LIMIT).to_i
  end

  def create_fluffy_account_with_min_throttling(limit = nil)
    create_fluffy_account(limit, Fluffy::ApiWrapper::MINUTE_GRANULARITY)
  end

  def enable_fluffy_min_level
    launch(:fluffy_min_level) if create_fluffy_account_with_min_throttling
  end

  def disable_fluffy_min_level
    rollback(:fluffy_min_level) if destroy_fluffy_account
  end

  def fluffy_integration_enabled?
    fluffy_enabled? || fluffy_min_level_enabled?
  end

end