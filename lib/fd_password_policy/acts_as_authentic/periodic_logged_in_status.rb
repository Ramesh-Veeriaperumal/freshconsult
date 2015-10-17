module FDPasswordPolicy
  module ActsAsAuthentic

    module PeriodicLoggedInStatus
      def self.included(klass)
        klass.class_eval do
          extend Config
          add_acts_as_authentic_module(Methods)
        end
      end

      # All configuration for the logged in status feature set.
      module Config
        # The timeout to determine when a user is logged in or not.
        #
        # * <tt>Default:</tt> nil
        # * <tt>Accepts:</tt> Fixnum
        def periodic_logged_in_timeout(value = nil)
          rw_config(:periodic_logged_in_timeout, value, {})
        end
        alias_method :periodic_logged_in_timeout=, :periodic_logged_in_timeout
      end

      # All methods for the logged in status feature seat.
      module Methods
        def self.included(klass)
          return if !klass.column_names.include?("current_login_at")

          klass.class_eval do
            include InstanceMethods
          end
        end

        module InstanceMethods
          def periodic_logged_in?
            
            return true unless send(periodic_logged_in_timeout[:if])
            raise "Can not determine the records login state because there is no current_login_at column" if !respond_to?(:current_login_at)
            !current_login_at.nil? && ((current_login_at.utc + send(periodic_logged_in_timeout[:duration])) > Time.now.utc)
          end

          def periodic_logged_out?
            !periodic_logged_in?
          end

          private
            def periodic_logged_in_timeout
              self.class.periodic_logged_in_timeout || {}
            end
        end
      end
    end
  end
end