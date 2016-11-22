class Integrations::SyncEntityMapping < ActiveRecord::Base
  serialize :configs, Hash

  belongs_to_account
  belongs_to :user
  belongs_to :sync_account, :class_name => "Integrations::SyncAccount"
  attr_protected :user_id, :sync_account_id
  before_create :set_account_id

  private
    def set_account_id
      self.account_id = sync_account.account_id
    end

end
