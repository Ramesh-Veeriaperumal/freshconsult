module FDPasswordPolicy
  module ActsAsAuthentic

    module PasswordFormat

      def self.included(klass)
        klass.class_eval do
          extend Config
          add_acts_as_authentic_module(Methods)
        end

      end

      module Config
          # Set the field to use for password history
          #
          # * <tt>Default:</tt> 0
          # * <tt>Accepts:</tt> Integer
          def password_history_field(value = nil)
            rw_config(:password_history_field, value, nil)
          end
          alias_method :password_history_field=, :password_history_field

          # Hash with condition to check if password history check is enabled and history depth if required
          #
          # * <tt>Default:</tt> false
          # * <tt>Accepts:</tt> Boolean
          def validate_password_history(value = nil)
            rw_config(:validate_password_history, value, {})
          end
          alias_method :validate_password_history=, :validate_password_history

          # Regex for validating the password format and the corresponding if condition 
          #
          # * <tt>Default:</tt> []
          # * <tt>Accepts:</tt> Array of {:regex => my_regex, :error => my_error_message}
          def password_format_options(value = nil)
            rw_config(:password_format_options, value, {})
          end
          alias_method :password_format_options=, :password_format_options
        
          # Toggles validating the password meets the minimum length
          #
          # * <tt>Default:</tt> false
          # * <tt>Accepts:</tt> Boolean
          def validate_password_length(value = nil)
            rw_config(:validate_password_length, value, {})
          end
          alias_method :validate_password_length=, :validate_password_length

          # Toggles validating the password does not match login
          #
          # * <tt>Default:</tt> false
          # * <tt>Accepts:</tt> Boolean
          def validate_password_contains_login(value = nil)
            rw_config(:validate_password_contains_login, value, {})
          end
          alias_method :validate_password_contains_login=, :validate_password_contains_login
      end

      module Methods
        def self.included(klass)
          klass.class_eval do
            after_validation :update_old_passwords
            validate :validate_password_format, :if => :require_password_changed?
          end
        end

        def require_password_changed?
          !new_record? && password_changed?
        end

        def validate_password_format
          password_not_short?
          password_repeated?
          password_format?
          password_contains_login?
          self.errors.any? ? false : true
        end

        def update_old_passwords
          if self.errors.empty? && send("#{crypted_password_field}_changed?") #&& send(validate_password_history[:if])
            history = pwd_history
            history.unshift({:password => send("#{crypted_password_field}"), :salt =>  send("#{password_salt_field}") })
            history = history[0, 5]
            update_option({:password_history => history})
          end
        end

        def password_history_field
          self.class.password_history_field
        end

        def password_format_options
          self.class.password_format_options || {}
        end

        def validate_password_history
          self.class.validate_password_history || {}
        end

        def validate_password_contains_login
          self.class.validate_password_contains_login || {}
        end

        def validate_password_length
          self.class.validate_password_length || {}
        end

        private

        def password_repeated?
          return if self.password.blank?
          if send(validate_password_history[:if]) 
            history = pwd_history
            depth = send(validate_password_history[:depth])
            history = history[0, depth]
            found = history.any? do |old_password|
              args = [self.password, old_password[:salt]].compact
              old_password[:password] == crypto_provider.encrypt(args)
            end
            error_msg_key = (depth == 1) ? 'password_policy.history' : 'password_policy.history_plural'
            self.errors.add(:base, I18n.t(error_msg_key, :history_depth => depth)) if found
          end
        end

        def password_format?
          return if self.password.blank?
         
          password_format_options.each do |option|
            if send(option[:if])
              found = self.password =~ option[:regex]
              self.errors.add(:base, option[:error]) unless found
            end
          end
        end

        def password_not_short?
          if send(validate_password_length[:if])
            min_length = send(validate_password_length[:min_length])
            short = self.password.blank? || self.password.length < min_length
            self.errors.add(:base, I18n.t('password_policy.min_length', :min_length => min_length)) if short
          end
        end

        def password_contains_login?
          if send(validate_password_contains_login[:if])
            login = send("#{self.class.login_field}")
            found = self.password.downcase.include? login.downcase #pwd contains whole login
            found = self.password.downcase.include?(login[/.+(?=@)/].downcase) if !found and login[/.+(?=@)/] #pwd contains username if login is email
            found = login.downcase.include? self.password.downcase if !found and login.length >= self.password.length #pwd is some part of login
            self.errors.add(:base, I18n.t('password_policy.username')) if found
          end
        end

        def update_option(option = {})
            send("#{password_history_field}=", (send("#{password_history_field}") || {}).deep_merge(option))
        end

        def pwd_history
          pwd_hash = send("#{password_history_field}") || {}
          history = pwd_hash.empty? || pwd_hash[:password_history].nil? ? [] : pwd_hash[:password_history]
        end

      end
    end
  end
end
