module Ember
  class ContactPasswordPoliciesController < ApiApplicationController

    include AgentContactConcern

    def index
      @password_policy = password_policy PasswordPolicy::USER_TYPE[:contact]
    end
  end
end
