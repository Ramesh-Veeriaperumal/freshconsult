class Admin::CannedResponses::Response < ActiveRecord::Base
  
  self.table_name =  "admin_canned_responses"    
  self.primary_key = :id
  
  include Mobile::Actions::CannedResponse
  include Search::ElasticSearchIndex
  include Helpdesk::Accessible::ElasticSearchMethods

  belongs_to_account

  has_many :shared_attachments,
    :as => :shared_attachable,
    :class_name => 'Helpdesk::SharedAttachment',
    :dependent => :destroy

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

  accepts_nested_attributes_for :helpdesk_accessible

  delegate :groups, :users, :visible_to_me?, :to => :helpdesk_accessible

  attr_accessor :visibility
  attr_protected :account_id

  validates_length_of :title, :in => 3..240
  validates_presence_of :folder_id
  before_validation :validate_title
  unhtml_it :content
  xss_sanitize :only =>[:content_html],  :html_sanitize => [:content_html]

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

   def to_indexed_json
    to_json({
        :root =>"admin/canned_responses/response", 
        :tailored_json => true, 
        :only => [:account_id, :title, :folder_id],
        :methods => [:es_access_type, :es_group_accesses, :es_user_accesses],
      })
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

end
