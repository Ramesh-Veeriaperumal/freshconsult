module FDPasswordPolicy
  module Session

    module PasswordExpiryTimeout

      def self.included(klass)
        klass.class_eval do
          extend Config
          include InstanceMethods

          after_persisting :enforce_password_expiry
        end
      end

      module Config
      end

      module InstanceMethods

        def password_stale?
          !stale_record.nil? || (web_or_api_request? && record && record.password_expired?)
        end

        # Can't be made private as it is being used by intercept_api_request module also. 
        def api_request?
          controller.request.path.try(:starts_with?, "/api/")
        end
    
        private
          
          def enforce_password_expiry
            if password_stale? && record
              record.password_expired = true
              self.stale_record = record
              self.record = nil
            end
          end

          def web_or_api_request?
            # 1.Should be checked if cookies has session.
            # 2.Should be checked only for api requests with email in authorization header.
            controller.cookies['_helpkit_session'] || (api_request? && !request_via_api_key?)
          end

          # Used by intercept_api_request module also. 
          def request_via_api_key?
            !controller.params[:k].try(:include?, "@")
          end

      end

    end
  end
end
