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

  def enable_fluffy_for_email(limit = nil, plan_id = nil)
    launch(:fluffy_email) if create_fluffy_email_account(limit, plan_id)
  end

  def disable_fluffy_for_email
    rollback(:fluffy_email) if destroy_fluffy_email_account
  end

  def change_fluffy_api_limit(limit = nil)
    if fluffy_enabled?
      limit ||= get_api_limit_from_redis(id, subscription.plan_id)
      Fluffy::FRESHDESK.update(full_domain, limit, HOUR_GRANULARITY)
    end
  end

  def change_fluffy_api_min_limit(plan_id = nil)
    if fluffy_min_level_enabled?
      plan_limits = get_api_min_limit_from_redis(plan_id || subscription.plan_id)
      Fluffy::FRESHDESK.update(full_domain, plan_limits[:limit], plan_limits[:granularity], plan_limits[:account_paths])
    end
  end

  def change_fluffy_email_limit(limit = nil, plan_id = nil)
    if fluffy_email_enabled?
      plan_limits = get_email_limit_from_redis(plan_id || subscription.plan_id)
      Fluffy::FRESHDESK_EMAIL.update(full_domain, id, limit || plan_limits[:limit], MINUTE_GRANULARITY, plan_limits[:account_paths] || [])
    end
  end

  def current_fluffy_limit(domain = full_domain)
    fluffy_account = Fluffy::FRESHDESK.find_account(domain)
    fluffy_account if fluffy_account.present? && fluffy_account.is_a?(Fluffy::Account)
  end

  def current_fluffy_email_limit(domain = full_domain)
    fluffy_account = Fluffy::FRESHDESK_EMAIL.find_account(domain, FRESH_DESK_EMAIL_PRODUCT)
    fluffy_account if fluffy_account.present? && fluffy_account.is_a?(Fluffy::AccountV2)
  end

  def fluffy_integration_enabled?
    fluffy_enabled? || fluffy_min_level_enabled?
  end

  def fluffy_addons_enabled?
    addons.any? { |addon| FLUFFY_ADDONS.include? addon.name }
  end

  def create_fluffy_account(limit = nil)
    limit ||= get_api_limit_from_redis(id, subscription.plan_id)
    Fluffy::FRESHDESK.create(full_domain, limit, HOUR_GRANULARITY)
  end

  def create_fluffy_email_account(limit = nil, plan_id = nil)
    plan_limits = get_email_limit_from_redis(plan_id || subscription.plan_id)
    Fluffy::FRESHDESK_EMAIL.create(full_domain, id, limit || plan_limits[:limit], MINUTE_GRANULARITY, plan_limits[:account_paths])
  end

  def destroy_fluffy_account(domain = full_domain)
    Fluffy::FRESHDESK.destroy(domain)
  end

  def destroy_fluffy_email_account(domain = full_domain)
    Fluffy::FRESHDESK_EMAIL.destroy(domain)
  end

  def create_fluffy_account_with_min_throttling(limit = nil, plan_id = nil)
    if limit.present?
      Fluffy::FRESHDESK.create(full_domain, limit, MINUTE_GRANULARITY)
    else
      plan_limits = get_api_min_limit_from_redis(plan_id || subscription.plan_id)
      Fluffy::FRESHDESK.create(full_domain, plan_limits[:limit], MINUTE_GRANULARITY, plan_limits[:account_paths])
    end
  end
end
