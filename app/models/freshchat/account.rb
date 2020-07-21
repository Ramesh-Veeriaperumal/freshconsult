class Freshchat::Account < ActiveRecord::Base
  
  include DataVersioning::Model
  include OmniChannelDashboard::TouchstoneUtil

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
end
