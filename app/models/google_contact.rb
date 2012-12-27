class GoogleContact < ActiveRecord::Base

	belongs_to_account
  belongs_to :user
  belongs_to :google_account, :class_name=>"Integrations::GoogleAccount", :autosave=>false
  attr_accessor :google_group_ids
  attr_protected :user_id, :google_account_id
  before_create :set_account_id

  private
  	def set_account_id
    	self.account_id = google_account.account_id
  	end
  
end
