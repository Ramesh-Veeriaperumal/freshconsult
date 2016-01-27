module FDPasswordPolicy
  module Session

    module InterceptApiRequest

      def self.included(klass)
        klass.class_eval do
          extend Config
          include InstanceMethods

          # Intercept validation and do api specific checks while request authentication gets proceeded.
          validate :intercept_workflow, :if => :api_request? # defined in passowrd_expiry_tmeout
        end
      end

      module Config
      end

      module InstanceMethods

        # Undo failed login if request is via API key
        # Handle consecutive failed login attempts differently for API
        def intercept_workflow
          undo_failed_login_count if request_via_api_key? # defined in passowrd_expiry_tmeout
          handle_consecutive_failed_logins if consecutive_failed_logins?
        end

        private

          def undo_failed_login_count
            if attempted_record && attempted_record.failed_login_count != attempted_record.failed_login_count_was
              attempted_record.failed_login_count =  attempted_record.failed_login_count_was
            end
          end

          def consecutive_failed_logins?
            errors.any? && errors.full_messages.include?("Consecutive failed logins limit exceeded, account has been temporarily disabled.")
          end

          def handle_consecutive_failed_logins
            if request_via_api_key?
              errors.clear
            else
              # Authlogic saves the record as validate could have changed some attribute.
              # failed login count should be saved if invalid pwd is given.
              # Since we are interrupting the flow with raising the excpetion, doing the save_record here.
              save_record(attempted_record) 
              raise ConsecutiveFailedLoginError.new(attempted_record.failed_login_count), "Consecutive failed logins limit exceeded"
            end
          end
          
      end

    end
  end
end
