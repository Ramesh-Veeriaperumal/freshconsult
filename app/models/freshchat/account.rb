class Freshchat::Account < ActiveRecord::Base
  
  include DataVersioning::Model

  CONFIG = YAML.load_file(File.join(Rails.root, 'config', 'freshchat.yml')).symbolize_keys

  VERSION_MEMBER_KEY = 'FRESHCHAT_ACCOUNT_LIST'.freeze

  self.table_name =  :freshchat_accounts
  self.primary_key = :id
  
  belongs_to_account
  serialize :preferences, Hash
  publishable
  concerned_with :presenter

  before_save :construct_model_changes, on: :update
  before_destroy :save_deleted_freshchat_account_info

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
