module BelongsToAccount

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def belongs_to_account
      belongs_to :account, :class_name => '::Account'
      default_scope do
        where(:account_id => ::Account.current.id) if ::Account.current
      end
      send :include, InstanceMethods
    end
  end

  module InstanceMethods
    def account
      ::Account.current || super
    end
  end
end
