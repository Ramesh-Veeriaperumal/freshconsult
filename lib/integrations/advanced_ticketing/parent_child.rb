class PlanUpgradeError < Exception; end
class Integrations::AdvancedTicketing::ParentChild

  include Integrations::AdvancedTicketing::AdvFeatureMethods

  def enable_parent_child(inst_app)
    return if current_account.parent_child_tickets_enabled?
    if fetch_advanced_features(:parent_child_tickets)
      add_feature(:parent_child_tickets)
    else
      raise PlanUpgradeError, 'ParentChild feature is not available for your plan.'
    end
  end

  def disable_parent_child(inst_app)
    Rails.logger.warn "Removed ParentChild :: #{caller[0..2]}"
  end
end