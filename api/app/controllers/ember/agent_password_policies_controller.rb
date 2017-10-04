module Ember
  class AgentPasswordPoliciesController < ApiApplicationController

    include AgentContactConcern

    def index
      @password_policy = password_policy PasswordPolicy::USER_TYPE[:agent]
    end
  end
end
