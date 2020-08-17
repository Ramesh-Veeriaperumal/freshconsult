class Subscription < ActiveRecord::Base
  def freddy_self_service_sessions
    SubscriptionPlan::FREDDY_DEFAULT_SESSIONS_MAP[:freddy_self_service] * renewal_period
  end

  def freddy_ultimate_sessions
    SubscriptionPlan::FREDDY_DEFAULT_SESSIONS_MAP[:freddy_ultimate] * renewal_period
  end

  def freddy_additional_pack_sessions
    SubscriptionPlan::FREDDY_DEFAULT_SESSIONS_MAP[:freddy_session_packs] * freddy_session_packs
  end
end
