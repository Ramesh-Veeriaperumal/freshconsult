class Freshchat::Account < ActiveRecord::Base
  
  include DataVersioning::Model
  include OmniChannelDashboard::TouchstoneUtil
  include Redis::OthersRedis
  include Redis::Keys::Others

  CONFIG = YAML.load_file(File.join(Rails.root, 'config', 'freshchat.yml')).deep_symbolize_keys

  VERSION_MEMBER_KEY = 'FRESHCHAT_ACCOUNT_LIST'.freeze

  self.table_name =  :freshchat_accounts
  self.primary_key = :id
  
  belongs_to_account
  serialize :preferences, Hash
  publishable
  concerned_with :presenter

  before_save :construct_model_changes, on: :update
  before_destroy :save_deleted_freshchat_account_info
  validates :app_id, presence: true
  after_commit :invoke_touchstone_account_worker, if: :omni_bundle_enabled?
  after_commit :handle_ocr_to_mars_redis_key

  attr_accessor :model_changes, :deleted_model_info

  [:portal_widget_enabled, :token].each do |method_name|
    define_method "#{method_name}" do
      self.preferences[method_name.to_s]
    end

    define_method "#{method_name}=" do |value|
      self.preferences.deep_merge!({"#{method_name}" => value })
    end
  end

  def api_domain
    URI::parse(Freshchat::Account::CONFIG[:apiHostUrl]).host
  end

  def construct_model_changes
    @model_changes = self.changes.clone.to_hash
    @model_changes.symbolize_keys!
  end

  def save_deleted_freshchat_account_info
    @deleted_model_info = as_api_response(:central_publish_destroy)
  end

  def handle_ocr_to_mars_redis_key
    return unless (Account.current || account).ocr_to_mars_api_enabled?
    if transaction_include_action?(:create)
      add_member_to_redis_set(OCR_TO_MARS_CHAT_ACCOUNT_IDS, app_id)
    elsif transaction_include_action?(:update)
      if @model_changes.key?(:enabled)
        enabled ? add_member_to_redis_set(OCR_TO_MARS_CHAT_ACCOUNT_IDS, app_id) : remove_member_from_redis_set(OCR_TO_MARS_CHAT_ACCOUNT_IDS, app_id)
      end
    elsif transaction_include_action?(:destroy)
      remove_member_from_redis_set(OCR_TO_MARS_CHAT_ACCOUNT_IDS, @deleted_model_info[:freshchat_account_id])
    end
  end

end
