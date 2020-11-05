class PlanUpgradeError < Exception; end
class Integrations::AdvancedTicketing::SharedOwnership

  include Integrations::AdvancedTicketing::AdvFeatureMethods

  def install(inst_app)
    return if current_account.shared_ownership_enabled?
    if fetch_advanced_features(:shared_ownership)
      enable_setting(:shared_ownership)
    else
      raise PlanUpgradeError, 'SharedOwnership feature is not available for your plan.'
    end
  end

  def uninstall(inst_app)
    Rails.logger.warn "Removed SharedOwnership :: #{caller[0..2]}"
  end
end