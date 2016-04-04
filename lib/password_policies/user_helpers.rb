module PasswordPolicies
  module UserHelpers

    def user_policy
      if self.agent?
        policy_account.agent_password_policy_from_cache 
      else
        policy_account.contact_password_policy_from_cache
      end
    end

    def password_history_enabled?
      user_policy && user_policy.password_history_enabled?
    end 

    def password_history_depth
      user_policy && user_policy.history_depth.to_i
    end

    def password_alphanumeric_enabled?
      user_policy && user_policy.password_alphanumeric_enabled?
    end 

    def password_special_character_enabled?
      user_policy && user_policy.password_special_character_enabled?
    end

    def password_mixed_case_enabled?
      user_policy && user_policy.password_mixed_case_enabled?
    end 

    def password_contains_login_enabled?
      user_policy && user_policy.password_contains_login_enabled?
    end

    def periodic_login_enabled?
      user_policy && policy_account.launched?(:periodic_login_feature) ? (user_policy.periodic_login_enabled?) : false
    end    

    def password_expiry_enabled?
      user_policy && login_via_password? && user_policy.password_expiry_enabled?
    end   

    def password_length_enabled?
      user_policy && user_policy.password_length_enabled?
    end 

    def periodic_login_duration
      user_policy && user_policy.periodic_login_duration && user_policy.periodic_login_duration.to_i.days
    end

    def password_expiry_duration
      user_policy && user_policy.password_expiry_duration && user_policy.password_expiry_duration.to_i.days
    end

    def minimum_password_length
      user_policy && user_policy.minimum_password_length && user_policy.minimum_password_length.to_i
    end

    def login_via_password?
      !policy_account.sso_enabled? && !self.authorizations.any?
    end

    def policy_account
      @policy_account ||= Account.current || self.account
    end

  end
end
