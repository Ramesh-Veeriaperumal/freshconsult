class HelpWidget < ActiveRecord::Base
  include MemcacheKeys
  validates :name, data_type: {rules: String}, custom_length: {maximum:  ApiConstants::MAX_LENGTH_STRING }
  validates :settings, data_type:{ rules: Hash }
  belongs_to_account

  serialize :settings, Hash

  concerned_with :constants, :presenter

  after_commit :clear_cache, :upload_configs

  default_scope order: 'created_at DESC'

  scope :active, conditions: { active: true }

  def captcha_enabled?
    settings[:contact_form][:captcha]
  end

  def ticket_fields_form?
    settings[:contact_form][:form_type] == HelpWidget::FORM_TYPES[:ticket_fields_form]
  end

  def predictive?
    settings[:components][:predictive_support]
  end

  def ticket_creation_enabled?
    contact_form_enabled? || predictive?
  end

  def contact_form_enabled?
    settings[:components][:contact_form]
  end

  def solution_articles_enabled?
    settings[:components][:solution_articles]
  end

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
