class PlanUpgradeError < Exception; end
class Integrations::AdvancedTicketing::LinkTicket

  include Integrations::AdvancedTicketing::AdvFeatureMethods

  def enable_link_tkt(inst_app)
    if fetch_advanced_features(:link_tickets)
      add_feature(:link_tickets)
    else
      raise PlanUpgradeError, 'LinkTicket feature is not available for your plan.'
    end
  end

  def disable_link_tkt(inst_app)
    remove_feature(:link_tickets)
  end
end