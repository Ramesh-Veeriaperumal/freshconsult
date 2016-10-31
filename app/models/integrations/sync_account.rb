class Integrations::SyncAccount < ActiveRecord::Base

  belongs_to_account
  belongs_to :sync_tag, :class_name => "Helpdesk::Tag"
  belongs_to :installed_application, :class_name => "Integrations::InstalledApplication"
  attr_accessible :account_id, :sync_tag_id
  serialize :configs, Hash
  has_many :sync_entity_mappings, :class_name => 'Integrations::SyncEntityMapping', :dependent => :delete_all

  def update_oauth_token(token)
    self.oauth_token = token
    self.save!
  end

  def update_last_sync_status(status)
    self.last_sync_status = status
    self.save!
  end

  def update_sync_group_id(group_id)
    self.sync_group_id = group_id
    self.save!
  end

end
