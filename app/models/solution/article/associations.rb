class Solution::Article < ActiveRecord::Base

	FEATURE_BASED_METHODS = [:folder]

	belongs_to :folder, :class_name => 'Solution::Folder'

  belongs_to :user, :class_name => 'User'

  belongs_to_account

  has_many :voters, :through => :votes, :source => :user, :uniq => true, :order => "#{Vote.table_name}.id DESC"
  
  has_many_attachments

  has_many_cloud_files

  has_many :activities,
    :class_name => 'Helpdesk::Activity',
    :as => 'notable'

  has_many :tag_uses,
    :as => :taggable,
    :class_name => 'Helpdesk::TagUse',
    :dependent => :destroy

  has_many :tags, 
    :class_name => 'Helpdesk::Tag',
    :through => :tag_uses

  has_many :support_scores, :as => :scorable, :dependent => :destroy

  has_many :article_ticket, :dependent => :destroy

  has_one :article_body, :autosave => true
  
  has_many :tickets, :through => :article_ticket, :source => :ticketable,
           :source_type => 'Helpdesk::Ticket', :order => 'created_at DESC'

  has_many :archive_tickets, :through => :article_ticket, :source => :ticketable, :source_type => 'Helpdesk::ArchiveTicket'
end