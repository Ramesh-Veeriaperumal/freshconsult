class Freshcaller::Account < ActiveRecord::Base
  include OmniChannelDashboard::TouchstoneUtil
  include Redis::OthersRedis
  include Redis::Keys::Others

  self.table_name =  :freshcaller_accounts
  self.primary_key = :id

  belongs_to_account
  publishable on: [:create, :destroy, :update]
  concerned_with :presenter, :constants

  serialize :settings, Hash

  before_save :construct_model_changes, on: :update
  before_destroy :save_deleted_freshchat_account_info
  after_commit :invoke_touchstone_account_worker, if: :omni_bundle_enabled?
  after_commit :handle_ocr_to_mars_redis_key
  after_commit :handle_agent_statuses_redis_key

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

  def handle_ocr_to_mars_redis_key
    return unless (Account.current || account).ocr_to_mars_api_enabled?

    handle_keys_on_actions(OCR_TO_MARS_CALLER_ACCOUNT_IDS)
  end

  def handle_agent_statuses_redis_key
    return unless (Account.current || account).agent_statuses_enabled?

    handle_keys_on_actions(AGENT_STATUSES_CALLER_ACCOUNT_IDS)
  end

  private

    def handle_keys_on_actions(redis_key)
      if transaction_include_action?(:create)
        add_member_to_redis_set(redis_key, freshcaller_account_id)
      elsif transaction_include_action?(:update)
        if @model_changes.key?(:enabled)
          enabled ? add_member_to_redis_set(redis_key, freshcaller_account_id) : remove_member_from_redis_set(redis_key, freshcaller_account_id)
        end
      elsif transaction_include_action?(:destroy)
        remove_member_from_redis_set(redis_key, @deleted_model_info[:freshcaller_account_id])
      end
    end

end
