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

        def web_or_api_request?
          controller.cookies['_helpkit_session'] || controller.request.path.starts_with?("/api/")
        end
    
        private
          
          def enforce_password_expiry
            if password_stale? && record
              record.password_expired = true
              self.stale_record = record
              self.record = nil
            end
          end

      end

    end
  end
end
