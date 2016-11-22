module Onboarding::OnboardingHelperMethods
  include Onboarding::OnboardingRedisMethods

  def complete_admin_onboarding
    complete_account_onboarding
    current_user.agent.update_attribute(:onboarding_completed, false)
  end

end
