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
          !stale_record.nil? || (controller.cookies['_helpkit_session'] && record && record.password_expired?)
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
