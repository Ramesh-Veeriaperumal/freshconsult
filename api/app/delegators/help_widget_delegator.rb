class HelpWidgetDelegator < BaseDelegator
  include ActiveRecord::Validations

  validate :validate_product , if: ->{ @product_id }
  validate :validate_widget_flow , if: ->{ @options.present? && @options[:widget_flow].present? }

  def initialize(record, options = {})
    @item = record
    @product_id = options[:product_id]
    @options = nil
    if options[:settings].present? && options[:settings][:components].present?
      @options = options[:settings]
    end
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

  private

    def contact_form_enabled
      @options[:components].key?("contact_form") ? @options[:components][:contact_form] : @item.contact_form_enabled?
    end

    def solution_articles_enabled
      @options[:components].key?("solution_articles") ?  @options[:components][:solution_articles] : @item.solution_articles_enabled?
    end

end
