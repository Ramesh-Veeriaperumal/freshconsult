module FDPasswordPolicy
  module ActsAsAuthentic
    module PasswordExpiryStatus
      def self.included(klass)
        klass.class_eval do
          extend Config
          add_acts_as_authentic_module(Methods)

          attr_accessor :password_expired
        end
      end

      # All configuration for the password expiry feature set.
      module Config
        # The timeout to determine when the password is expired
        #
        # * <tt>Default:</tt> nil
        # * <tt>Accepts:</tt> Fixnum
        def password_expiry_timeout(value = nil)
          rw_config(:password_expiry_timeout, value, {})
        end
        alias_method :password_expiry_timeout=, :password_expiry_timeout

        # Set the field to use for password expiry
        #
        # * <tt>Default:</tt> nil
        # * <tt>Accepts:</tt> Integer
        def password_expiry_field(value = nil)
          rw_config(:password_expiry_field, value, nil)
        end
        alias_method :password_expiry_field=, :password_expiry_field

      end


      # All methods for the password expiry feature.
      module Methods
        def self.included(klass)

          klass.class_eval do
            include InstanceMethods
            after_validation :update_password_expiry_date
          end
        end
        
          
        module InstanceMethods
          # Returns true if Time.now.utc < expiry.to_time
          def password_active?
            raise "Can not determine the records login state because there is no current_login_at column" if !respond_to?(:current_login_at)
            return true unless safe_send(password_expiry_timeout[:if])
            expiry = ((safe_send("#{password_expiry_field}") || {})[:password_expiry_date])
            return true if expiry.nil?
            Time.now.utc < expiry.to_time
          end

          def password_expired?
            !password_active?
          end

          def set_password_expiry(option = {}, save_record = true)
            set_expiry(option)
            self.save if save_record
          end
          
          def password_expiry
            expiry = (safe_send("#{password_expiry_field}") || {})[:password_expiry_date]
            expiry.to_time if expiry
          end

          def update_password_expiry_date
            if self.errors.empty? && safe_send("#{crypted_password_field}_changed?") && safe_send(password_expiry_timeout[:if]) 
              last_date = Time.now.utc + safe_send(password_expiry_timeout[:duration])
              set_expiry({:password_expiry_date => last_date.to_s})
            end
          end

          private
            def password_expiry_timeout
              self.class.password_expiry_timeout || {}
            end

            def password_expiry_field
              self.class.password_expiry_field
            end
            
            def set_expiry(option = {})
              safe_send("#{password_expiry_field}=", (safe_send("#{password_expiry_field}") || {}).deep_merge(option))
            end
        end
      end
    end
  end
end
