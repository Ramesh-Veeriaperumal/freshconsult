class Freshcaller::Account < ActiveRecord::Base
  self.table_name =  :freshcaller_accounts
  self.primary_key = :id
  
  belongs_to_account
  publishable on: [:create, :destroy]
  concerned_with :presenter

  before_destroy :save_deleted_freshchat_account_info

  attr_accessor :model_changes, :deleted_model_info

  def save_deleted_freshchat_account_info
    @deleted_model_info = as_api_response(:central_publish_destroy)
  end
end
