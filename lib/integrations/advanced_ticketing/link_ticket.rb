class PlanUpgradeError < Exception; end
class Integrations::AdvancedTicketing::LinkTicket

  include Integrations::AdvancedTicketing::AdvFeatureMethods

  def enable_link_tkt(inst_app)
    return if current_account.link_tickets_enabled?
    if fetch_advanced_features(:link_tickets)
      add_feature(:link_tickets)
    else
      raise PlanUpgradeError, 'LinkTicket feature is not available for your plan.'
    end
  end

  def disable_link_tkt(inst_app)
    Rails.logger.warn "Removed LinkedTicket :: #{caller[0..2]}"
  end
end