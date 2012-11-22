class Admin::CannedResponses::Folder < ActiveRecord::Base

  set_table_name "ca_folders"

  belongs_to :account
  
  has_many :canned_responses, 
    :class_name => 'Admin::CannedResponses::Response', 
    :foreign_key => "folder_id",
    :dependent => :destroy

  attr_accessible :name
  validates_length_of :name, :in => 3..240
  validates_uniqueness_of :name, :scope => :account_id

  named_scope :accessible_for, lambda { |agent_user|
    {
      :joins => %(inner join 
      (select distinct(folder_id) from admin_canned_responses 
      INNER JOIN admin_user_accesses acc ON
      admin_canned_responses.account_id=%<account_id>i AND 
      acc.accessible_id = admin_canned_responses.id AND 
      acc.accessible_type = 'Admin::CannedResponses::Response' AND 
      acc.account_id = admin_canned_responses.account_id 
      LEFT JOIN agent_groups ON acc.group_id=agent_groups.group_id
      where acc.VISIBILITY=%<visible_to_all>s OR 
      agent_groups.user_id=%<user_id>i OR 
      (acc.VISIBILITY=%<only_me>s and acc.user_id=%<user_id>i)) as accessible_folders
      on `ca_folders`.id=accessible_folders.folder_id) % {
        :visible_to_all => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents], 
        :only_me => Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
        :user_id => agent_user.id,
        :account_id => agent_user.account_id},
      :order => "is_default DESC"
    }
  }

  before_destroy :confirm_destroy

  protected 

    def confirm_destroy
      if is_default?
        self.errors.add_to_base("Cannot delete default folder!!")
        return false
      end
    end

end
