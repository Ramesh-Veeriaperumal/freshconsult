module BelongsToAccount
  
  def self.included(base) 
    base.extend ClassMethods
  end
  
  module ClassMethods
    def belongs_to_account
      belongs_to :account
  
      default_scope do
        { :conditions => { :account_id => Account.current.id } } if Account.current
      end
      
      before_create :set_account_id
      
      include InstanceMethods
    end
  end
  
  module InstanceMethods
       
    protected
      
      def set_account_id
        self.account = Account.current if Account.current
      end
  end
  
end