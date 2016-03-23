module BelongsToAccount

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def belongs_to_account
      belongs_to :account, :class_name => '::Account'
      eval %(
        class_eval do
          def account_with_no_query
            ::Account.current || account_without_no_query
          end
          alias_method_chain :account,:no_query
        end
      )
      default_scope do
        where(:account_id => ::Account.current.id) if ::Account.current
      end

    end
  end
end
