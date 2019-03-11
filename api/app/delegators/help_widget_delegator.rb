class HelpWidgetDelegator < BaseDelegator
  include ActiveRecord::Validations

  validate :validate_product, if: -> { @product_id }
  validate :validate_widget_flow, if: -> { @options.present? && @options[:widget_flow].present? }
  validate :validate_domain_list, if: -> { @options.present? && domain_list_or_predictive }

  def initialize(record, options = {})
    @item = record
    @product_id = options[:product_id]
    @options = nil
    @options = options[:settings] if options[:settings].present?
  end

  def validate_product
    product_ids = Account.current.products_from_cache.collect(&:id)
    unless product_ids.include?(@product_id)
      errors[:product_id] << :inaccessible_value
    end
  end

  def validate_widget_flow
    unless contact_form_enabled && solution_articles_enabled
      errors[:widget_flow] << :inaccessible_field
    end
  end

  def validate_domain_list
    if predictive_support_enabled && domain_list_blank
      errors[:domain_list] << I18n.t('help_widget.domain_list_empty')
    end
  end

  private

    def contact_form_enabled
      if @options[:components].present? && @options[:components].key?('contact_form')
        @options[:components][:contact_form]
      else
        @item.contact_form_enabled?
      end
    end

    def solution_articles_enabled
      if @options[:components].present? && @options[:components].key?('solution_articles')
        @options[:components][:solution_articles]
      else
        @item.solution_articles_enabled?
      end
    end

    def predictive_support_enabled
      if @options[:components].present? && @options[:components].key?(:predictive_support)
        @options[:components][:predictive_support]
      else
        @item.predictive?
      end
    end

    def domain_list_blank
      if @options[:predictive_support].present? && @options[:predictive_support].key?(:domain_list)
        @options[:predictive_support][:domain_list].blank?
      else
        @item.settings[:predictive_support].blank? || @item.settings[:predictive_support][:domain_list].blank?
      end
    end

    def domain_list_or_predictive
      (@options[:predictive_support].present? && @options[:predictive_support].key?(:domain_list)) ||
        (@options[:components].present? && @options[:components].key?(:predictive_support))
    end
end
