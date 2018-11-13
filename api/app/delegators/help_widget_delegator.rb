class HelpWidgetDelegator < BaseDelegator
  include ActiveRecord::Validations

  validate :validate_product , if: ->{ @product_id }

  def initialize(record, options = {})
    @product_id=options[:product_id]
  end

  def validate_product
    product_ids = Account.current.products_from_cache.collect(&:id)
    unless product_ids.include?(@product_id)
      errors[:product_id] << :inaccessible_value
    end
  end
end
