class HelpWidget < ActiveRecord::Base
  include MemcacheKeys
  validates :name, data_type: {rules: String}, custom_length: {maximum:  ApiConstants::MAX_LENGTH_STRING }
  validates :settings, data_type:{ rules: Hash }
  belongs_to_account

  serialize :settings, Hash

  concerned_with :constants, :presenter

  after_commit :clear_cache, :upload_configs

  scope :active, conditions: { active: true }

  private

    def upload_configs
      args = {
        widget_id: self.id,
        _destroy: transaction_include_action?(:destroy) || !active
      }
      HelpWidget::UploadConfig.perform_async(args)
    end

    def clear_cache
      key = HELP_WIDGETS % { :account_id => self.account_id, :id => self.id }
      MemcacheKeys.delete_from_cache key
    end
end
