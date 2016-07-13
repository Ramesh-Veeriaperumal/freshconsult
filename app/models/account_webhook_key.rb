# encoding: utf-8
class AccountWebhookKey < ActiveRecord::Base
  self.table_name = :account_webhook_keys
  self.primary_key = :id
  
  include Cache::Memcache::AccountWebhookKeyCache

  belongs_to :account
  
  after_commit :clear_account_webhook_key_cache, on: :update
end
