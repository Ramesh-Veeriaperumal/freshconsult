module FDPasswordPolicy
  module ActsAsAuthentic
    module ApiAuthentication
      def self.included(klass)
        klass.class_eval do
          add_acts_as_authentic_module(Methods)

        end
      end

      module Methods
        def self.included(klass)

          klass.class_eval do
            include InstanceMethods
          end
        end
        
        # Methods to mimic authlogic failed_login_count update.  
        module InstanceMethods
          # failed_login_count increases for each consecutive failed login.
          # See Authlogic::Session::BruteForceProtection and the consecutive_failed_logins_limit config option for more details.
          def update_failed_login_count(valid_pwd, user_name = nil, ip = nil)
            if valid_pwd
              # reset failed_login_count only when it has changed. This is to prevent unnecessary save on user.
              # don't reset failed login count if he reached max failed login attepmt.
              if self.failed_login_count != 0 && !has_reached_max_failed_login_attempt?
                self.failed_login_count = 0 
                self.save
              end
            else
              self.failed_login_count ||= 0
              self.failed_login_count = failed_login_ban_expired? ? 1 : self.failed_login_count + 1
              self.save
              Rails.logger.error "API Unauthorized Error: Failed login attempt '#{self.failed_login_count}' for '#{user_name}' from #{ip} at #{Time.now.utc}"
            end
            handle_consecutive_failed_login_attempt(valid_pwd)
          end
          
          def has_reached_max_failed_login_attempt?
            return @failed_login_count_exceeded if defined?(@failed_login_count_exceeded)
            @failed_login_count_exceeded ||= (self.failed_login_count >= UserSession.consecutive_failed_logins_limit && !failed_login_ban_expired?)
          end

          private
            def failed_login_ban_expired?
              return @reset if defined?(@reset)
              @reset ||= (UserSession.failed_login_ban_for > 0 && self.updated_at < UserSession.failed_login_ban_for.seconds.ago)
            end

            # Raise error if consecutive failed login attempts are reached.
            def handle_consecutive_failed_login_attempt(valid_pwd)
              if has_reached_max_failed_login_attempt?  
                raise ConsecutiveFailedLoginError.new(self.failed_login_count), "Consecutive failed logins limit exceeded" 
              else
                valid_pwd ? self : nil
              end
            end

        end
      end
    end
  end
end