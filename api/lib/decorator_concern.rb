module DecoratorConcern
  extend ActiveSupport::Concern

  ACTION_MAPPING = {
    decorate_object: [:create, :update, :show],
    decorate_objects: [:index]
  }
  DECORATOR_METHOD_MAPPING = ACTION_MAPPING.each_with_object({}) { |(k, v), inverse| v.each { |e| inverse[e] = k } }

  module ClassMethods
    attr_reader :decorator_method_mapping

    def decorate_views(options = {})
      custom_options = ACTION_MAPPING.merge(options)
      custom_method_mapping = custom_options.each_with_object({}) { |(k, v), inverse| v.each { |e| inverse[e] = k } }
      @decorator_method_mapping = DECORATOR_METHOD_MAPPING.merge(custom_method_mapping)
      alias_method_chain :render, :before_render_action
    end

    def decorator_name
      # name is a class variable, will be computed only once when class is loaded.
      @name ||= "#{name.gsub('Controller', '').gsub(/Pipe::|Channel::/, '').gsub('Api', '').singularize}Decorator".constantize
    end
  end

  def decorator_method
    @decorator_method ||= 
        (self.class.decorator_method_mapping || 
          self.class.superclass.decorator_method_mapping)[action_name.to_sym]
  end

  def render_with_before_render_action(*options, &block)
    send(decorator_method) if decorator_method
    render_without_before_render_action(*options, &block)
  end

  def decorate_objects
    return if @errors || @error
    # To create multiple decorator objects if the views involve considerable cosmetic manipulations.
    decorator, options = decorator_options
    @items.map! { |item| decorator.new(item, options) }
  end

  def decorate_object
    return if @errors || @error
    # To create decorator object if the views involve considerable cosmetic manipulations.
    if decorator_options
      decorator, options = decorator_options
      @item = decorator.new(@item, (options || {}))
    end
  end

  def decorator_options(options = {})
    [self.class.decorator_name, options]
  end
end
