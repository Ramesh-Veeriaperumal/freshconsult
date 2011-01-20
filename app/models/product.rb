class Product < ActiveRecord::Base
  belongs_to :account
  has_one :forum_category, :dependent => :destroy
  
  before_create :set_account_id_in_children
  
  def forum_category_attributes=(fc_attributes)
    build_forum_category(fc_attributes)
  end
  
  protected
    def set_account_id_in_children
      self.forum_category.account_id = account_id
    end
end
