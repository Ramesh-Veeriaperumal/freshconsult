module BelongsToAccount
  
  def self.included(base) 
    base.extend ClassMethods
  end
  
  module ClassMethods
    def belongs_to_account
      belongs_to :account
      # TODO-RAILS3 Its too bad need to check some other way......temp
      default_scope do
        where(:account_id => Account.current.id) if (column_names.include?("account_id") && Account.current)
      end

    end
  end
end