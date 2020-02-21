class Account < ActiveRecord::Base
  include Fluffy::Constants

  def enable_fluffy
    launch(:fluffy) if create_fluffy_account
  end

  def disable_fluffy
    rollback(:fluffy) if destroy_fluffy_account
  end

  def enable_fluffy_min_level(limit = nil, plan_id = nil)
    launch(:fluffy_min_level) if create_fluffy_account_with_min_throttling(limit, plan_id)
  end

  def disable_fluffy_min_level
    rollback(:fluffy_min_level) if destroy_fluffy_account
  end

  def change_fluffy_api_limit(limit = nil)
    if fluffy_enabled?
      fluffy_account = Fluffy::ApiWrapper.new(full_domain)
      limit ||= get_api_limit_from_redis(id, subscription.plan_id)
      fluffy_account.update(limit, HOUR_GRANULARITY)
    else
      Rails.logger.info "FLUFFY is not enabled for this account"
    end
  end

  def change_fluffy_api_min_limit(plan_id = nil)
    if fluffy_min_level_enabled?
      fluffy_account = Fluffy::ApiWrapper.new(full_domain)
      plan_limits = get_api_min_limit_from_redis(plan_id || subscription.plan_id)
      fluffy_account.update(plan_limits[:limit], plan_limits[:granularity], plan_limits[:account_paths])
    else
      Rails.logger.info "FLUFFY min level is not enabled for this account"
    end
  end

  def current_fluffy_limit(domain = full_domain)
    fluffy_account = Fluffy::ApiWrapper.find_by_domain(domain)
    fluffy_account if fluffy_account.present? && fluffy_account.is_a?(Fluffy::Account)
  end

  def fluffy_integration_enabled?
    fluffy_enabled? || fluffy_min_level_enabled?
  end

  def fluffy_addons_enabled?
    addons.any? { |addon| FLUFFY_ADDONS.include? addon.name }
  end

  def create_fluffy_account(limit = nil)
    limit ||= get_api_limit_from_redis(id, subscription.plan_id)
    Fluffy::ApiWrapper.create(full_domain, limit, HOUR_GRANULARITY)
  end

  def destroy_fluffy_account(domain = full_domain)
    fluffy_account = Fluffy::ApiWrapper.new(domain)
    fluffy_account.destroy
  end

  def create_fluffy_account_with_min_throttling(limit = nil, plan_id = nil)
    if limit.present?
      Fluffy::ApiWrapper.create(full_domain, limit, MINUTE_GRANULARITY)
    else
      plan_limits = get_api_min_limit_from_redis(plan_id || subscription.plan_id)
      Fluffy::ApiWrapper.create(full_domain, plan_limits[:limit], MINUTE_GRANULARITY, plan_limits[:account_paths])
    end
  end
end
