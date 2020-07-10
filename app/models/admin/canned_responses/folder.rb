class Admin::CannedResponses::Folder < ActiveRecord::Base
  self.primary_key = :id
  self.table_name =  "ca_folders"

  belongs_to_account

  has_many :canned_responses,
    :class_name => 'Admin::CannedResponses::Response',
    :foreign_key => "folder_id",
    :conditions => { :deleted => false },
    :dependent => :destroy

  has_many :all_canned_responses,
    :class_name => 'Admin::CannedResponses::Response',
    :foreign_key => "folder_id",
    :dependent => :destroy

  attr_accessor :visible_responses_count
  attr_accessible :name
  validates_length_of :name, :in => 3..240
  validates_uniqueness_of :name, :scope => :account_id, :case_sensitive => false

  concerned_with :presenter
  publishable on: [:create, :destroy]

  FOLDER_TYPE = [
    [:personal, "Personal", 100],
    [:default,  "General",  200],
    [:others,   "Custom",   300]
  ]

  FOLDER_TYPE_KEYS_BY_TOKEN = Hash[*FOLDER_TYPE.map { |i| [i[0], i[2]] }.flatten]
  FOLDER_NAMES_BY_TOKEN     = Hash[*FOLDER_TYPE.map { |i| [i[0], i[1]] }.flatten]

  scope :exclude_personal_folder, -> { where('folder_type != 100') }

  scope :accessible_for, -> (agent_user) {
    select('ca_folders.*, available_responses_count').
    joins(%(inner join
            (select folder_id, count(admin_canned_responses.id) as available_responses_count
              from admin_canned_responses
              INNER JOIN admin_user_accesses acc ON
              admin_canned_responses.account_id=%<account_id>i AND
              acc.accessible_id = admin_canned_responses.id AND
              acc.accessible_type = 'Admin::CannedResponses::Response' AND
              acc.account_id = admin_canned_responses.account_id
              LEFT JOIN agent_groups ON acc.group_id=agent_groups.group_id
              where acc.VISIBILITY=%<visible_to_all>s OR
              agent_groups.user_id=%<user_id>i OR
              (acc.VISIBILITY=%<only_me>s and acc.user_id=%<user_id>i) group by folder_id) as accessible_folders
              on `ca_folders`.id=accessible_folders.folder_id) % {
                visible_to_all: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
                only_me: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
                user_id: agent_user.id,
                account_id: agent_user.account_id
              }).
    order('folder_type')
  }

  scope :personal_folder,  -> { where(folder_type: FOLDER_TYPE_KEYS_BY_TOKEN[:personal]) }
  scope :general_folder, -> { where(folder_type: FOLDER_TYPE_KEYS_BY_TOKEN[:default]) }
  scope :default_folder, -> { where(is_default: true) }
  scope :editable_folder, -> { where(folder_type: FOLDER_TYPE_KEYS_BY_TOKEN[:others]) }


  before_save :set_folder_type, :create_model_changes
  before_destroy :confirm_destroy
  after_commit :delete_ca_response, :on => :update, :if => :deleted?
  after_commit :central_publisher_action, on: :update

  def create_model_changes
    @model_changes = changes.to_hash
    @model_changes.symbolize_keys!
  end

  def central_publisher_action
    if @model_changes.key?(:deleted) && deleted
      @deleted_model_info = central_publish_payload
      central_publish_action(:destroy)
    else
      central_publish_action(:update)
    end
  end

  def personal?
    self.folder_type == FOLDER_TYPE_KEYS_BY_TOKEN[:personal]
  end

  def display_name
    if is_default?
      return personal? ? I18n.t("canned_folders.Personal"): I18n.t("canned_folders.General")
    else
      return self.name
    end
  end

  protected

    def confirm_destroy
      if is_default?
        self.errors.add(:base,"Cannot delete default folder!!")
        return false
      end
    end

    def delete_ca_response
      canned_responses.find_each do |ca|
        ca.soft_delete!
      end
    end

  def set_folder_type
    self.folder_type = FOLDER_TYPE_KEYS_BY_TOKEN[:others] if self.folder_type.nil?
  end
end
