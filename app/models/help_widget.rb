class HelpWidget < ActiveRecord::Base
  include MemcacheKeys

  validates :name, data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :settings, data_type: { rules: Hash }
  belongs_to_account
  has_many :help_widget_solution_categories, class_name: 'HelpWidgetSolutionCategory', dependent: :destroy, inverse_of: :help_widget
  has_many :help_widget_suggested_article_rules, class_name: 'HelpWidgetSuggestedArticleRule', dependent: :destroy, inverse_of: :help_widget, order: :position

  accepts_nested_attributes_for :help_widget_solution_categories, allow_destroy: true

  serialize :settings, Hash

  concerned_with :constants, :presenter

  after_commit :clear_cache, :upload_configs

  before_destroy :save_deleted_help_widget_info

  default_scope -> { order('created_at DESC') }

  scope :active, ->{ where(active: true) }

  publishable on: [:create, :destroy]
  publishable on: :update, if: -> { model_changes.present? }

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

  def contact_form_require_login?
    contact_form_enabled? && settings[:contact_form][:require_login]
  end

  def build_help_widget_solution_categories(category_meta_ids)
    category_ids_in_db = help_widget_solution_categories.pluck(:solution_category_meta_id)
    categories_to_delete = category_ids_in_db - category_meta_ids
    categories_to_add = category_meta_ids - category_ids_in_db

    category_attributes_array = []

    if categories_to_delete.present?
      item_ids = help_widget_solution_categories.where(solution_category_meta_id: categories_to_delete).pluck(:id)
      category_attributes_array = item_ids.map { |id| category_hash(id) }
    end

    category_attributes_array |= categories_to_add.map { |category_id| category_hash(nil, category_id) } if categories_to_add.present?

    self.help_widget_solution_categories_attributes = category_attributes_array if category_attributes_array.present?
  end

  def upload_configs
    args = {
      widget_id: id,
      _destroy: transaction_include_action?(:destroy) || !active
    }
    HelpWidget::UploadConfig.perform_async(args)
  end

  def help_widget_suggested_article_rules_from_cache
    key = format(HELP_WIDGET_SUGGESTED_ARTICLE_RULES, account_id: account_id, help_widget_id: id)
    fetch_from_cache(key) { help_widget_suggested_article_rules.select([:id, :conditions]).as_json(root: false) }
  end

  private

    def model_changes
      @model_changes = previous_changes || {}
      @model_changes.slice!(*PUBLISHABLE_COLUMNS)
      @model_changes
    end

    def save_deleted_help_widget_info
      @deleted_model_info = as_api_response(:central_publish_destroy)
    end

    def clear_cache
      key = HELP_WIDGETS % { :account_id => self.account_id, :id => self.id }
      MemcacheKeys.delete_from_cache key
    end

    def category_hash(id, category_meta_id = nil)
      { id: id, solution_category_meta_id: category_meta_id, _destroy: id.present? }
    end
end
