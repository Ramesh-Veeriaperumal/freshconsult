class Freshcaller::Account < ActiveRecord::Base
  include OmniChannelDashboard::TouchstoneUtil

  self.table_name =  :freshcaller_accounts
  self.primary_key = :id

  belongs_to_account
  publishable on: [:create, :destroy, :update]
  concerned_with :presenter

  before_save :construct_model_changes, on: :update
  before_destroy :save_deleted_freshchat_account_info
  after_commit :invoke_touchstone_account_worker, if: :omni_bundle_enabled?

  attr_accessor :model_changes, :deleted_model_info

  def construct_model_changes
    @model_changes = changes.clone.to_hash
    @model_changes.symbolize_keys!
  end

  def save_deleted_freshchat_account_info
    @deleted_model_info = as_api_response(:central_publish_destroy)
  end

  def enable
    update_attributes(enabled: true)
  end

  def disable
    update_attributes(enabled: false)
  end
end
