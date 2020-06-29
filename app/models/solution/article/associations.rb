class Solution::Article < ActiveRecord::Base

	belongs_to :folder, :class_name => 'Solution::Folder'

  belongs_to :user, :class_name => 'User'

  belongs_to_account

  has_many :solution_template_mappings,
           class_name: 'Solution::TemplateMapping',
           inverse_of: :article

  has_many :voters, 
    :through => :votes, 
    :source => :user,
    :order => "#{Vote.table_name}.id DESC",
    :uniq => true

  has_many_attachments

  has_many_cloud_files

  has_many :activities,
    :class_name => 'Helpdesk::Activity',
    :as => 'notable'

  has_many :tag_uses,
    :class_name => 'Helpdesk::TagUse',
    :as => :taggable,
    :dependent => :destroy

  has_many :tags,
           class_name: 'Helpdesk::Tag',
           through: :tag_uses,
           after_add: :add_tag_activity,
           after_remove: :remove_tag_activity

  has_many :support_scores, :as => :scorable, :dependent => :destroy

  has_many :article_ticket, :dependent => :destroy

  has_one :article_body, :autosave => true
  
  has_many :tickets, 
    :through => :article_ticket, 
    :source => :ticketable,
    :source_type => 'Helpdesk::Ticket', 
    :order => 'created_at DESC'

  has_many :archive_tickets, 
    :through => :article_ticket, 
    :source => :ticketable, 
    :source_type => 'Helpdesk::ArchiveTicket'
	
	belongs_to :solution_article_meta,
    :class_name => "Solution::ArticleMeta",
    :foreign_key => "parent_id",
    :readonly => false

  has_one :solution_folder_meta,
    :through => :solution_article_meta,
    :class_name => "Solution::FolderMeta",
    :readonly => false

  has_many :solution_article_versions,
    class_name: 'Solution::ArticleVersion',
    dependent: :destroy,
    inverse_of: :article

  has_one :live_version, 
    class_name: 'Solution::ArticleVersion',
    conditions: { live: true }

  has_one :helpdesk_approval,
           class_name: 'Helpdesk::Approval',
           dependent: :destroy,
           as: :approvable,
           inverse_of: :approvable
end
