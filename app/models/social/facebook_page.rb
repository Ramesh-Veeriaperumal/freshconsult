class Social::FacebookPage < ActiveRecord::Base
  set_table_name "social_facebook_pages" 
  belongs_to :account 
  belongs_to :product, :class_name => 'EmailConfig'
  
  named_scope :active, :conditions => ["enable_page=?", true] 
   
  validates_uniqueness_of :page_id, :scope => :account_id, :message => "Page has been already added"
   
end
