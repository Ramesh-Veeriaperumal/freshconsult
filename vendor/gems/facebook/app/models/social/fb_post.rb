class Social::FbPost < ActiveRecord::Base
  
  self.table_name =  "social_fb_posts"
  self.primary_key = :id
  
  include Facebook::Constants
  
  has_ancestry :orphan_strategy => :rootify
  
  attr_accessible :post_id, :facebook_page_id, :msg_type, :post_attributes, :ancestry
  
  belongs_to :postable, :polymorphic => true
  belongs_to_account
  belongs_to :facebook_page , :class_name => 'Social::FacebookPage'
  
  attr_protected :postable_id
  
  validates_presence_of   :post_id, :account_id
  validates_uniqueness_of :post_id, :scope => :account_id, :message => "Post already converted as a ticket/ticket"
  
  serialize :post_attributes, Hash
  
  scope :latest_thread, lambda {|thread_id , num| {:conditions => ["social_fb_posts.thread_id=? and postable_type=?", thread_id,'Helpdesk::Ticket'],
                                                   :order => 'created_at DESC',
                                                   :limit => num}}
                                                                                                   
                                                   
  def post?
    msg_type == 'post'
  end

  def message?
    msg_type == 'dm'
  end

  def realtime_message?
    message? and facebook_page.realtime_messaging
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
   
  def fb_post?
    post_type == POST_TYPE_CODE[:post]
  end
   
  def original_post_id
    original_fb_post_id ? original_fb_post_id : self.post_id
  end
   
  def type
    case post_type
    when fb_post?
      by_visitor? ? FEED_TYPES["post"] : FEED_TYPES["status"]
    when comment?
      FEED_TYPES["comment"]
    when reply_to_comment?
      FEED_TYPES["reply_to_comment"]
    end
   end
   
   def user
    self.is_ticket? ? self.postable.requester : self.postable.user
   end
   
 private
   def post_attributes_present?
    !self.post_attributes.blank?
   end
   
   def post_type
    self.post_attributes[:post_type] if post_attributes_present?
   end
   
   def original_fb_post_id
    self.post_attributes[:original_post_id] if post_attributes_present?
   end
   
   def by_visitor?
    self.facebook_page.id != user.fb_profile_id
   end
 
end
