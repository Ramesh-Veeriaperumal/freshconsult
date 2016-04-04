module FDPasswordPolicy
  module Session

    module PeriodicLoginTimeout

      def self.included(klass)
        klass.class_eval do
          extend Config
          include InstanceMethods
          #after_persisting :enforce_periodic_login #TBD enable after Phase 1
        end
      end

      module Config
      end

      module InstanceMethods
        # Tells you if the login period is stale or not.
        def login_period_stale?
          !stale_record.nil? || (record && record.periodic_logged_out?)
        end
    
        private
          
          def enforce_periodic_login
            if login_period_stale?
              self.stale_record = record
              self.record = nil
            end
          end
      end

    end
  end
end
