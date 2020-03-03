class Solution::Draft < ActiveRecord::Base

  include Solution::SolutionMethods
  
  self.table_name = "solution_drafts"
  self.primary_key = :id
  serialize :meta, Hash

  belongs_to_account
  belongs_to :user
  belongs_to :article, :class_name => "Solution::Article", inverse_of: :draft, :readonly => false
  belongs_to :category_meta, :class_name => "Solution::CategoryMeta"
  
  has_one :draft_body, :class_name => "Solution::DraftBody", :autosave => true, :dependent => :destroy
  has_many_attachments
  has_many_cloud_files

  delegate :description, :to => :draft_body, :allow_nil => true

  validates_uniqueness_of :article_id, :if => 'article_id.present?'
  validates_presence_of :title, :description, :user_id , :account_id
  validates_length_of :title, :in => 3..240
  validates_numericality_of :user_id

  before_validation :populate_defaults
  before_save :change_modified_at, :encode_emoji_in_articles
  before_destroy :discard_notification

  attr_accessible :title, :meta, :description
  attr_accessor :discarding, :publishing, :keep_previous_author, :session, :cancelling, :unpublishing, :false_delete_attachment_trigger, :restored_version, :skip_version_creation

  alias_attribute :modified_by, :user_id
  alias_attribute :body, :draft_body
  alias_attribute :name, :title

  default_scope :order => "modified_at DESC"

  scope :as_list_view, :include => { 
    :user => [], 
    :article => {:solution_article_meta => {:solution_folder_meta => :primary_folder}},
    :category_meta => []
  }
  scope :for_sidebar, :include => [:user]
  
  scope :by_user, lambda { |user|
     { 
       :conditions => ["solution_drafts.user_id = ?", user.id ]
     }
  }

  scope :in_portal, lambda { |portal| 
    {
      :conditions => {
        :category_meta_id => portal.portal_solution_categories.map(&:solution_category_meta_id)
      }
    }
  }

  scope :in_applicable_languages, lambda {
    {
      :joins => [:article],
      :conditions => ['solution_articles.language_id in (?)', Account.current.all_language_ids]
    }
  }

  STATUSES = [
    [ :editing,     "solutions.draft.status.editing",        0 ], 
    [ :work_in_progress, "solutions.draft.status.work_in_progress",    1 ]
    # [ :rework, "solutions.draft.status.rework",    2 ],
    # [ :ready_to_publish, "solutions.draft.status.ready_to_publish",    3 ]
  ]

  # STATUS_OPTIONS  = STATUSES.map { |i| [i[1], i[2]] }
  # STATUS_NAMES_BY_KEY = Hash[*STATUSES.map { |i| [i[2], i[1]] }.flatten]
  STATUS_KEYS_BY_TOKEN  = Hash[*STATUSES.map { |i| [i[0], i[2]] }.flatten]

  LOCKDOWN_PERIOD = 2.hours

  COMMON_ATTRIBUTES = ["title", "description"]
  #defining writer method for delegated attribute

  def description= content
    unless self.draft_body.present?
      self.build_draft_body({
        :description => content, 
        :account_id => Account.current.id
      }) and return content
    end
    self.draft_body.description = content
  end

  def locked?
    return false unless status == STATUS_KEYS_BY_TOKEN[:editing]
    return false if User.current.id == self.user_id
    self.updated_at > (Time.now.utc - LOCKDOWN_PERIOD)
  end

  def lock_for_editing
    return false if self.locked?
    self.status, self.user_id = STATUS_KEYS_BY_TOKEN[:editing], User.current.id
    true
  end

  def unlock
    self.status = STATUS_KEYS_BY_TOKEN[:work_in_progress]
  end

  def unlock!(skip_versioning = false)
    unlock
    if skip_versioning
      self.skip_version_creation = true
      self.save
      self.skip_version_creation = false
    else
      self.save
    end
  end

  def populate_defaults
    self.status ||= STATUS_KEYS_BY_TOKEN[:work_in_progress]
    self.user_id = User.current && !keep_previous_author ? User.current.id : (user_id || article.user_id)
    self.category_meta_id ||= article.solution_folder_meta.solution_category_meta_id
  end

  def change_modified_at
    return if self.modified_at_changed?
    self.modified_at ||= Time.now.utc
    self.modified_at = Time.now.utc  if (self.draft_body.changed? || self.title_changed?)
  end

  def publish!
    COMMON_ATTRIBUTES.each do |attr|
      article.safe_send("#{attr}=", self.safe_send(attr))
    end

    move_attachments
    article.modified_by = user_id
    self.publishing = true if article.published?
    self.article.publish!
    self.publishing = false
    self.reload
    self.destroy
  end
  
  def folder
    article.solution_article_meta.solution_folder_meta.primary_folder
  end

  def to_s
    article.to_s
  end

  def discard_notification
    return unless discarding && (User.current.id != self.user_id && self.user.email.present?)
    portal = Portal.current || Account.current.main_portal
    DraftMailer.send_later(
      :discard_notification,
      { :description => self.description, :title => self.title}, 
      self.article, self.user, User.current, portal, locale_object: self.user
    )

  end

  def updation_timestamp
    draft_body.present? ? [updated_at, draft_body.updated_at].max.to_i : (updated_at || 0).to_i
  end

  def deleted_attachments type
    (meta[:deleted_attachments] || {})[type] || []
  end

  def self.my_drafts(portal_id, language_id)
    my_drafts_scoper = where(user_id: User.current.id).joins(:article, category_meta: :portal_solution_categories).where('portal_solution_categories.portal_id = ? AND solution_articles.language_id = ?', portal_id, language_id)
    Account.current.article_approval_workflow_enabled? ? my_drafts_scoper.joins("LEFT JOIN helpdesk_approvals ON solution_drafts.article_id = helpdesk_approvals.approvable_id AND helpdesk_approvals.account_id = #{Account.current.id} AND approvable_type = 'Solution::Article'").where('helpdesk_approvals.id is NULL') : my_drafts_scoper
  end

  private

    def move_attachments
      [:attachments, :cloud_files].each do |assoc|
        article.safe_send(assoc).where( :id => self.deleted_attachments(assoc) ).destroy_all
        article.draft.safe_send(assoc).where( :id => self.deleted_attachments(assoc) ).destroy_all
        self.safe_send(assoc).each do |item|
          item.update_attributes(item.object_type => article)
        end
      end
    end
end
