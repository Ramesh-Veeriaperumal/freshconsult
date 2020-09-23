# encoding: utf-8
require 'digest/md5'

class Helpdesk::SpamNote < Helpdesk::Mysql::DynamicTable
  self.abstract_class = true
  belongs_to_account
  belongs_to :user, :class_name => 'User'
  has_many_attachments
  has_many_cloud_files
  belongs_to :spam_ticket, :class_name => 'Helpdesk::SpamTicket'
  has_one :tweet, :as => :tweetable, :class_name => 'Social::Tweet', :dependent => :destroy
  has_one :fb_post, :as => :postable, :class_name => 'Social::FbPost',  :dependent => :destroy

  has_many :shared_attachments,
           :as => :shared_attachable,
           :class_name => 'Helpdesk::SharedAttachment',
           :dependent => :destroy

  has_many :attachments_sharable, :through => :shared_attachments, :source => :attachment, :conditions => ["helpdesk_attachments.account_id=helpdesk_shared_attachments.account_id"]


  serialize :associations_data
  attr_protected :account_id
end