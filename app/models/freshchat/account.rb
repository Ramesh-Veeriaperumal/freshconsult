class Freshchat::Account < ActiveRecord::Base
  
  include DataVersioning::Model

  CONFIG = YAML.load_file(File.join(Rails.root, 'config', 'freshchat.yml')).symbolize_keys

  VERSION_MEMBER_KEY = 'FRESHCHAT_ACCOUNT_LIST'.freeze

  self.table_name =  :freshchat_accounts
  self.primary_key = :id
  
  belongs_to_account
  serialize :preferences, Hash

  [:portal_widget_enabled, :token].each do |method_name|
    define_method "#{method_name}" do
      self.preferences[method_name.to_s]
    end

    define_method "#{method_name}=" do |value|
      self.preferences.deep_merge!({"#{method_name}" => value })
    end
  end
end
