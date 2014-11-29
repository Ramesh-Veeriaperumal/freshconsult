class Social::FbPost < ActiveRecord::Base
  
  set_table_name "social_fb_posts"
  
  has_ancestry :orphan_strategy => :rootify
  
  belongs_to :postable, :polymorphic => true
  belongs_to_account
  belongs_to :facebook_page , :class_name => 'Social::FacebookPage'
  
  attr_protected :postable_id
  
  validates_presence_of   :post_id, :account_id
  validates_uniqueness_of :post_id, :scope => :account_id, :message => "Post already converted as a ticket/ticket"
  
  serialize :post_attributes, Hash
  
  named_scope :latest_thread, lambda {|thread_id , num| {:conditions => ["social_fb_posts.thread_id=? and postable_type=?", thread_id,'Helpdesk::Ticket'],
                                                   :order => 'created_at DESC',
                                                   :limit => num}}
                                                   
 def post?
   msg_type == 'post'
 end

 def message?
   msg_type == 'dm'
 end
 
 def is_ticket?
  postable_type.eql?('Helpdesk::Ticket')
 end

 def is_note?
  postable_type.eql?('Helpdesk::Note')
 end
  
end
