class Admin::CannedResponses::Response < ActiveRecord::Base
  
  self.table_name =  "admin_canned_responses"    
  self.primary_key = :id
  
  include Mobile::Actions::CannedResponse

  belongs_to_account

  has_many :shared_attachments,
    as: :shared_attachable,
    class_name: 'Helpdesk::SharedAttachment',
    dependent: :destroy,
    after_add: :touch_attachment_change,
    after_remove: :touch_attachment_change


  has_many :attachments_sharable, :through => :shared_attachments, :source => :attachment

  #has_many :attachments_, :class_name => 'Helpdesk::Attachment', :through => :shared_attachments

  belongs_to :folder, :class_name => "Admin::CannedResponses::Folder"

  has_many :agent_groups ,
    :through =>:accessible ,
    :foreign_key => "group_id" ,
    :source => :group

  has_one :helpdesk_accessible,
    :class_name => "Helpdesk::Access",
    :as => 'accessible',
    :dependent => :destroy

  has_many :groups,
           through: :helpdesk_accessible,
           source: :groups

  has_many :users,
           through: :helpdesk_accessible,
           source: :users

  accepts_nested_attributes_for :helpdesk_accessible

  delegate :visible_to_me?, to: :helpdesk_accessible

  attr_accessor :visibility, :attachment_removed, :action_destroy
  attr_accessible :title, :content_html, :folder_id, :helpdesk_accessible_attributes

  concerned_with :presenter
  publishable on: [:create, :update, :destroy]

  validates_length_of :title, :in => 3..240
  validates_presence_of :folder_id
  before_validation :validate_title
  unhtml_it :content
  xss_sanitize :only =>[:content_html],  :cannedresponse_sanitizer => [:content_html]

  after_commit :clear_inline_images_cache, on: :create
  after_commit :clear_inline_images_cache, on: :update
  before_save :create_model_changes

  scope :accessible_for, lambda { |user|
    {
      :joins => %(JOIN admin_user_accesses acc ON
                  admin_canned_responses.account_id=%<account_id>i AND
                  acc.accessible_id = admin_canned_responses.id AND
                  acc.accessible_type = 'Admin::CannedResponses::Response' AND
                  acc.account_id = admin_canned_responses.account_id
                  LEFT JOIN agent_groups ON
                  acc.group_id=agent_groups.group_id) % { :account_id => user.account_id },
      :conditions => %(acc.VISIBILITY=%<visible_to_all>s
                       OR agent_groups.user_id=%<user_id>i OR
      (acc.VISIBILITY=%<only_me>s and acc.user_id=%<user_id>i )) % {
        :visible_to_all => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
        :only_me => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
        :user_id => user.id
      }
    }
  }

  scope :only_me, lambda { |user|
    {
      :joins => %(JOIN helpdesk_accesses acc ON
                  acc.accessible_id = admin_canned_responses.id AND
                  acc.accessible_type = 'Admin::CannedResponses::Response' AND
                  admin_canned_responses.account_id=%<account_id>i AND
                  acc.account_id = admin_canned_responses.account_id
                  inner join user_accesses ON acc.id= user_accesses.access_id AND
                  acc.account_id= user_accesses.account_id) % { :account_id => user.account_id },
      :conditions => %(acc.access_type=%<only_me>s and user_accesses.user_id=%<user_id>i ) % {
        :only_me => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users],
        :user_id => user.id
      }
    }
  }

  scope :folder_responses_by_title, lambda { |response|
    {
      :conditions => ["admin_canned_responses.title=? and admin_canned_responses.folder_id=?", response.title, response.folder_id]
    }
  }

  INCLUDE_ASSOCIATIONS_BY_CLASS = {
    Admin::CannedResponses::Response => { :include => [:folder, {:helpdesk_accessible => [:group_accesses, :user_accesses]}]}
  }

  def create_model_changes
    @model_changes = changes.to_hash
    visibility_changes = helpdesk_accessible.changes
    @model_changes = @model_changes.merge('visibility' => visibility_changes.to_hash.symbolize_keys!) if visibility_changes.present?
    @group_access_changes = helpdesk_accessible.group_changes
    @model_changes.symbolize_keys!
  end

  def touch_attachment_change(attachment)
    return if attachment.attachment_id.blank?

    attachment_hash = { id: attachment.attachment_id, name: attachment.attachment.content_file_name }
    @attachment_changes ||= []
    @attachment_changes << attachment_hash
  end

  def to_indexed_json
    to_json({
        :root =>"admin/canned_responses/response", 
        :tailored_json => true, 
        :only => [:account_id, :title, :folder_id],
        :methods => [:es_access_type, :es_group_accesses, :es_user_accesses],
      })
  end

  def to_count_es_json
    to_json({
      :root =>false,
      :tailored_json => true,
      :only => [:account_id, :title, :folder_id],
      :methods => [:es_access_type, :es_group_accesses, :es_user_accesses],
    })
  end

  def soft_delete!
    self.deleted = true
    @deleted_model_info = central_publish_payload
    self.update_column(:deleted, true)
    self.action_destroy = true
    self.central_publish_action(:destroy)
  end

  def canned_response_url
    "#{account.full_url}/api/v2/canned_responses/#{id}"
  end

  private

  def validate_title
    if (!visible_only_to_me? && (self.title_changed? || self.folder_id_changed?))
      response = Account.current.canned_responses.folder_responses_by_title(self)
      response=response.select{|resp| resp.id!=self.id} if !self.new_record?
      if !response.nil? && response.any?
        self.errors.add(:base,I18n.t('canned_responses.errors.duplicate_title'))
        return false
      end
      true
    end
    true
  end

  def visible_only_to_me?
    self.helpdesk_accessible.access_type == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
  end

  def clear_inline_images_cache
    Account.current.clear_canned_responses_inline_images_from_cache
  end
end
