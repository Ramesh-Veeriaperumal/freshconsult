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

    end
  end
end
