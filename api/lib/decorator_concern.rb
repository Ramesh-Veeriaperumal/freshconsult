module DecoratorConcern
  extend ActiveSupport::Concern

  included do
    alias_method_chain :render, :before_render_action
    define_callbacks :render
  end

  module ClassMethods
    def append_before_render_action(*names)
      # names => [:decorate_objects, {only: <>, except: <>}]
      # extract_options! will remove and return the last hash from names. i.e. {only: <>, except: <>}
      options = names.extract_options!
      normalize_callback_option(options, :only, :if)
      normalize_callback_option(options, :except, :unless)
      names.each do |name|
        set_callback :render, :before, name, options
      end
    end
    alias_method :before_render, :append_before_render_action

    def normalize_callback_option(options, from, to)
      if from = options[from]
        from = Array(from).map { |o| "action_name == '#{o}'" }.join(' || ')
        options[to] = Array(options[to]).unshift(from)
      end
    end

    def decorate_views(options = {})
      options.reverse_merge!(collection: [:index], object: [:update, :create, :show])

      send(:before_render, :decorate_objects, only: options[:collection]) unless options[:collection].empty?
      send(:before_render, :decorate_object, only: options[:object]) unless options[:object].empty?
    end

    def decorator_name
      # name is a class variable, will be computed only once when class is loaded.
      @name ||= "#{name.gsub('Controller', '').gsub('Api', '').singularize}Decorator".constantize
    end
  end

  def render_with_before_render_action(*options, &block)
    run_callbacks :render, action_name do
      render_without_before_render_action *options, &block
    end
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
