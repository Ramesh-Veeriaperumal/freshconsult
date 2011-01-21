class Product < ActiveRecord::Base
  belongs_to :account
  
  has_many :tickets, :class_name => 'Helpdesk::Ticket'
  has_one :forum_category, :dependent => :destroy
  
  before_save :set_account_id_in_children
  
  def forum_category_attributes=(fc_attributes)
    #build_forum_category(fc_attributes) unless fc_attributes[:name].empty?
    unless fc_attributes[:name].empty?
      return build_forum_category(fc_attributes) if forum_category.nil?
      
      forum_category.update_attributes(fc_attributes)
    end
  end
  
  protected
    def set_account_id_in_children
      self.forum_category.account_id = account_id unless forum_category.nil?
    end
end
