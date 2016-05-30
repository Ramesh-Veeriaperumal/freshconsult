class BaseDrop < Liquid::Drop
  
  class_attribute :liquid_attributes
  self.liquid_attributes = [:object_id]
  
  attr_reader :source
  delegate :hash, :to => :source
  
  def initialize(source)
    @source = source
    @liquid = liquid_attributes.inject({}) do |h, k| 
      h.update k.to_s => @source.send(k) if @source.respond_to?(k)
    end
  end
  
  def context=(current_context)
    #current_context.registers[:controller].send(:cached_references) << @source if @source && current_context.registers[:controller]
    
    # @portal is set for every drop except PortalDrop, or you get into an infinite loop
    @portal = current_context['current_portal'].source.to_liquid if 
      !is_a?(PortalDrop) && @portal.nil? && current_context['current_portal']

    # Pagination variables for when liquid is created with pagination
    @per_page = current_context['per_page'].presence
    @page = current_context['page'].presence

    page_number_sanitize

    super
  end

  def before_method(method)
    @liquid[method.to_s]
  end

  def eql?(comparison_object)
    self == (comparison_object)
  end
  
  def ==(comparison_object)
    self.source == (comparison_object.is_a?(self.class) ? comparison_object.source : comparison_object)
  end

  # converts an array of records to an array of liquid drops, and assigns the given context to each of them
  def self.liquify(current_context, *records, &block)
    i = -1
    records = 
      records.inject [] do |all, r|
        i+=1
        attrs = (block && block.arity == 1) ? [r] : [r, i]
        all << (block ? block.call(*attrs) : r.to_liquid)
        all.last.context = current_context if all.last.is_a?(Liquid::Drop)
        all
      end
    records.compact!
    records
  end

  protected
    # def self.timezone_dates(*attrs)
    #   attrs.each do |attr_name|
    #     module_eval <<-end_eval
    #       def #{attr_name}
    #         class << self; attr_reader :#{attr_name}; end
    #         @#{attr_name} = (@source.#{attr_name} ? @site.timezone.utc_to_local(@source.#{attr_name}) : nil)
    #       end
    #     end_eval
    #   end
    # end
    
    def portal_user
      @portal_user ||= User.current
    end

    def portal_account
      @portal_account ||= Account.current
    end

    def allowed_in_portal? f
      portal_user || feature?(f)
    end

    def feature? f
      portal_account.features? f
    end
    
    def liquify(*records, &block)
      self.class.liquify(@context, *records, &block)
    end

    def page_number_sanitize
      return unless @page
      @page = max_page and return if respond_to?(:max_page, true) && (@page == "last" or @page.to_i > max_page)
      @page = 1 if @page.to_i.to_s != @page || @page.to_i <= 0
    end
end