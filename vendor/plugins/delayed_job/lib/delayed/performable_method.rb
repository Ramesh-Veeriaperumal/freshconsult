module Delayed
  class PerformableMethod < Struct.new(:object, :method, :args)
    attr_accessor :account
    
    CLASS_STRING_FORMAT = /^CLASS\:([A-Z][\w\:]+)$/
    AR_STRING_FORMAT    = /^AR\:([A-Z][\w\:]+)\:(\d+)$/

    def initialize(object, method, args)
      raise NoMethodError, "undefined method `#{method}' for #{self.inspect}" unless object.respond_to?(method)

      self.object = dump(object)
      self.args   = args.map { |a| dump(a) }
      self.method = method.to_sym
      self.account = dump(Account.current) if Account.current
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
       account_id = nil
       if account
        account =~ AR_STRING_FORMAT
        account_id = $2
       end
       Sharding.select_shard_of(account_id) do
        load(account).send(:make_current) if account
        load(object).send(method, *args.map{|a| load(a)})
      end
      rescue ActiveRecord::RecordNotFound
           # We cannot do anything about objects which were deleted in the meantime
      true
    end

    private

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
  end
end