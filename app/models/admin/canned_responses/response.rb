class Admin::CannedResponses::Response < ActiveRecord::Base

  set_table_name "admin_canned_responses"
  include Mobile::Actions::CannedResponse

  belongs_to_account

  has_many :shared_attachments,
    :as => :shared_attachable,
    :class_name => 'Helpdesk::SharedAttachment',
    :dependent => :destroy

  has_many :attachments_sharable, :through => :shared_attachments, :source => :attachment

  #has_many :attachments_, :class_name => 'Helpdesk::Attachment', :through => :shared_attachments

  belongs_to :folder, :class_name => "Admin::CannedResponses::Folder"

  has_one :accessible,
    :class_name => 'Admin::UserAccess',
    :as => 'accessible',
    :dependent => :destroy

  has_many :agent_groups ,
    :through =>:accessible ,
    :foreign_key => "group_id" ,
    :source => :group

  has_one :helpdesk_accessible,
    :class_name => "Helpdesk::Access",
    :as => 'accessible',
    :dependent => :destroy

  delegate :groups, :users, :to => :helpdesk_accessible

  attr_accessor :visibility
  attr_accessible :title, :content, :visibility, :content_html, :folder_id

  validates_length_of :title, :in => 3..240
  validates_presence_of :folder_id
  before_validation :validate_title, on: [:create,:update]

  unhtml_it :content
  xss_sanitize :only =>[:content_html],  :html_sanitize => [:content_html]

  after_create :create_accesible
  after_update :save_accessible


  named_scope :accessible_for, lambda { |user|
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

  named_scope :only_me, lambda { |user|
    {
      :joins => %(JOIN admin_user_accesses acc ON
                  acc.accessible_id = admin_canned_responses.id AND
                  acc.accessible_type = 'Admin::CannedResponses::Response' AND
                  admin_canned_responses.account_id=%<account_id>i AND
                  acc.account_id = admin_canned_responses.account_id) % { :account_id => user.account_id },
      :conditions => %(acc.VISIBILITY=%<only_me>s and acc.user_id=%<user_id>i ) % {
        :only_me => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
        :user_id => user.id
      }
    }
  }

  named_scope :folder_responses_by_title, lambda { |response|
    {
      :conditions => ["admin_canned_responses.title=? and admin_canned_responses.folder_id=?", response.title, response.folder_id]
    }
  }


  private

  def create_accesible
    self.accessible = Admin::UserAccess.new({:account_id => account_id }.merge(self.visibility))
    self.save
  end

  def save_accessible
    self.accessible.update_attributes(self.visibility)
  end

  def validate_title
    if (!visible_only_to_me? && (self.title_changed? || self.folder_id_changed?))
      response = Account.current.canned_responses.folder_responses_by_title(self)
      if !response.nil? && response.any?
        self.errors.add_to_base(I18n.t('canned_responses.errors.duplicate_title'))
        return false
      end
      true
    end
    true
  end

  def visible_only_to_me?
    visibility = self.visibility.nil? ? self.accessible.visibility : self.visibility["visibility"].to_i
    visibility == Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]
  end

end
