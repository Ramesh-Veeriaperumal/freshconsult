module Delayed
  class PerformableMethod < Struct.new(:object, :method, :args, :account, :portal, :locale_object)
    # attr_accessor :account
    
    CLASS_STRING_FORMAT = /^CLASS\:([A-Z][\w\:]+)$/
    AR_STRING_FORMAT    = /^AR\:([A-Z][\w\:]+)\:(\d+)$/

    def initialize(object, method, args, account = Account.current, portal = Portal.current)
      raise NoMethodError, "undefined method `#{method}' for #{self.inspect}" unless object.respond_to?(method)

      Rails.logger.debug "$$$$$$$$ Method -- #{method.to_sym} ------------- account #{Account.current}" 
      self.object = dump(object)
      self.locale_object = (args.last.is_a?(Hash) && args.last.key?(:locale_object)) ? args.pop[:locale_object] : nil
      self.args   = args.map { |a| dump(a) }
      self.method = method.to_sym
      self.account = dump(Account.current) if Account.current
      self.portal = dump(Portal.current) if Portal.current
    end
    
    def display_name  
      case self.object
      when CLASS_STRING_FORMAT then "#{$1}.#{method}"
      when AR_STRING_FORMAT    then "#{$1}##{method}"
      else "Unknown##{method}"
      end      
    end    

    def perform
       Account.reset_current_account
       Portal.reset_current_portal

       account_id = nil
       if account
        account =~ AR_STRING_FORMAT
        account_id = $2
       end
       Sharding.select_shard_of(account_id) do
        load(account).safe_send(:make_current) if account
        load(portal).safe_send(:make_current) if portal
        set_locale
        load(object).safe_send(method, *args.map{|a| load(a)})
        set_default_locale
        # $statsd.increment "email_counter.#{account_id}"
      end
      true
    rescue ShardNotFound => e
        Rails.logger.info("Shard not found. #{e.inspect} Account : #{account_id}")
        false
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.info("Record not found. #{e.inspect} Account : #{account_id}")
      false
    end

    private

    def set_locale
      self.locale_object = Account.current.users.find_by_email(locale_object) if !valid_locale_object? && valid_email?(locale_object)
      I18n.locale = valid_locale_object? ? locale_object.language : Account.current.default_account_locale
    end

    def set_default_locale
      I18n.locale = I18n.default_locale
    end

    def load(arg)
      case arg
      when CLASS_STRING_FORMAT then $1.constantize
      when AR_STRING_FORMAT    then $1.constantize.find($2)
      else arg
      end
    end

    def dump(arg)
      case arg
      when Class              then class_to_string(arg)
      when ActiveRecord::Base then ar_to_string(arg)
      else arg
      end
    end

    def ar_to_string(obj)
      "AR:#{obj.class}:#{obj.id}"
    end

    def class_to_string(obj)
      "CLASS:#{obj.name}"
    end

    def valid_locale_object?
      locale_object.present? && locale_object.respond_to?(:language)
    end

    def valid_email?(email)
      email =~ AccountConstants::EMAIL_REGEX
    end
  end
end
