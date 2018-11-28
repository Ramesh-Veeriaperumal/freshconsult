module FilterFactory::Filter
  class Base
    include FilterFactory::HelperMethods

    attr_accessor :select, :conditions, :order_by, :order_type, :page,
                  :per_page, :preloads, :source, :errors, :or_conditions

    def initialize(args = {})
      @args = args
      initialize_attributes(args)
    end
  end
end
