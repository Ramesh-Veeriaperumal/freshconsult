class PlanUpgradeError < Exception; end
class Integrations::AdvancedTicketing::SharedOwnership

  include Integrations::AdvancedTicketing::AdvFeatureMethods

  def install(inst_app)
    if fetch_advanced_features(:shared_ownership)
      add_feature(:shared_ownership)
    else
      raise PlanUpgradeError, 'SharedOwnership feature is not available for your plan.'
    end
  end

  def uninstall(inst_app)
    remove_feature(:shared_ownership)
  end
end