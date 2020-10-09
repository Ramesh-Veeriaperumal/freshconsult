class BaseDrop < Liquid::Drop
  
  class_attribute :liquid_attributes
  self.liquid_attributes = [:object_id]
  
  attr_reader :source
  delegate :hash, :to => :source
  
  def initialize(source)
    @source = source
    @liquid = liquid_attributes.inject({}) do |h, k| 
      h.update k.to_s => @source.safe_send(k) if @source.respond_to?(k)
    end
  end
  
  def context=(current_context)
    #current_context.registers[:controller].safe_send(:cached_references) << @source if @source && current_context.registers[:controller]
    
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
  
  # Overriding to silent ignore errors with empty string
  #
  def invoke_drop(method_or_key)
    super(method_or_key) rescue "" 
  end
  
  # Overriding to avoid aliasing to superclass
  #
  alias :[] :invoke_drop

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

  def customer_portal?
    return @customer_portal if instance_variable_defined?("@customer_portal")
    begin
      @customer_portal = (@context.registers[:controller].try(:class).try(:parent).to_s == "Support")
    rescue Exception => e
      @customer_portal = false
    end
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
      portal_user || (AccountSettings::SettingsConfig[f] ? portal_account.safe_send("#{f}_enabled?") : feature?(f))
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

    def escape_liquid_attribute(value)
      escape_liquid_attributes? ? h(value) : value
    end

    # Escape liquid attributes by default for portal and based on attribute in other places
    def escape_liquid_attributes?
      customer_portal? || @source.escape_liquid_attributes
    end

    def formatted_field_value(field_type, field_value)
      case (field_type.blank? ? :default : field_type.to_sym) 
      when :custom_paragraph
         escape_liquid_attribute(field_value).gsub(/\n/, '<br/>').html_safe #adding html_safe so that the return value is of ActiveSupport::SafeBuffer class.
      when :custom_text
        escape_liquid_attribute(field_value)
      when :custom_date
        formatted_date(field_value)
      when :encrypted_text
        nil
      else 
        field_value
      end
    end
end
