class Social::FbPost < ActiveRecord::Base
  
  include Facebook::Constants
  
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
 
 def post_type_present?
  post_attributes_present? and !self.post_attributes[:post_type].blank?
 end
 
 def can_comment?
  post_attributes_present? and self.post_attributes[:can_comment]
 end
 
 def comment?
  post_type == POST_TYPE_CODE[:comment]
 end
 
 def reply_to_comment?
  post_type == POST_TYPE_CODE[:reply_to_comment]
 end
 
 def post?
  post_type == POST_TYPE_CODE[:post]
 end
 
 private
   def post_attributes_present?
    !self.post_attributes.blank?
   end
   
   def post_type
    self.post_attributes[:post_type] if post_attributes_present?
   end
 
end
