module PasswordPolicies
    module Configs
        include FDPasswordPolicy::Constants

        def configs
            # set default values to the configs if it's blank.
            read_attribute(:configs).blank? ? DEFAULT_CONFIGS : read_attribute(:configs)
        end

        def configs=(config={})
            write_attribute(:configs, DEFAULT_CONFIGS.deep_merge(config))
        end
            
        def history_depth
            self.configs["cannot_be_same_as_past_passwords"]
        end

        def periodic_login_duration
            self.configs["session_expiry"]
        end

        def password_expiry_duration
            self.configs["password_expiry"]
        end
        
        def minimum_password_length
            self.configs["minimum_characters"]
        end
            
    end
end