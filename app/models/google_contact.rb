class GoogleContact < ActiveRecord::Base

  belongs_to :user
  belongs_to :google_account, :class_name=>"Integrations::GoogleAccount"
  attr_accessor :google_group_ids
  attr_protected :user_id, :google_account_id
end
