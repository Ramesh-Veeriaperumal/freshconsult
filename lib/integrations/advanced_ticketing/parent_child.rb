class PlanUpgradeError < Exception; end
class Integrations::AdvancedTicketing::ParentChild

  include Integrations::AdvancedTicketing::AdvFeatureMethods

  def enable_parent_child(inst_app)
    if fetch_advanced_features(:parent_child_tickets)
      add_feature(:parent_child_tickets)
    else
      raise PlanUpgradeError, 'ParentChild feature is not available for your plan.'
    end
  end

  def disable_parent_child(inst_app)
    remove_feature(:parent_child_tickets)
  end
end