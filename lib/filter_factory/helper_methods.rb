module FilterFactory
  module HelperMethods
    DEFAULT_SELECT = :all
    DEFAULT_CONDITIONS = [].freeze
    DEFAULT_ORDER_BY = :created_at
    DEFAULT_ORDER_TYPE = :desc
    DEFAULT_PAGE = 1
    DEFAULT_PER_PAGE = 30
    DEFAULT_PRELOADS = [].freeze
    DEFAULT_OR_CONDITIONS = [].freeze

    ATTRIBUTES = [:select, :conditions, :order_by, :order_type, :page, :per_page, :preloads, :or_conditions].freeze

    # ATTRIBUTES.each do |attribute|
    #   define_method attribute.to_s do
    #     options[attribute] ? options[attribute] : "DEFAULT_#{attribute.upcase}".constantize
    #   end
    # end

    def initialize_attributes(options)
      ATTRIBUTES.each do |attribute|
        instance_variable_set("@#{attribute}".to_sym, options[attribute] || "FilterFactory::HelperMethods::DEFAULT_#{attribute.upcase}".constantize)
      end
    end
  end
end
