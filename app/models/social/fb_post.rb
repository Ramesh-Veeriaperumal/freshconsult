class Social::FbPost < ActiveRecord::Base
  
  set_table_name "social_fb_posts"
  
  belongs_to :postable, :polymorphic => true
  belongs_to :account
  belongs_to :facebook_page , :class_name => 'Social::FacebookPage'
  
  attr_protected :postable_id
  
  validates_presence_of   :post_id, :account_id
  validates_uniqueness_of :post_id, :scope => :account_id, :message => "Post already converted as a ticket/ticket"
  
end
