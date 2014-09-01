module Liquid
	class TemplateInFormat < Template
		
    class << self		
      def parse(source, content_type = nil)
        template = TemplateInFormat.new
        template.parse(source, content_type)
        template
      end

      def parse_hash(source, content_type = nil)
        template = TemplateInFormat.new
        template.parse_hash(source, content_type)
        template
      end
    end

    def parse(source, content_type)
    	@root = DocumentInFormat.new(tokenize(source), content_type)
    	self
    end

    def parse_hash(source, content_type)
      @root = DocumentInFormat.new(tokenize_hash(source), content_type)
      self
    end

    def tokenize_hash(source)
      source = source.source if source.respond_to?(:source)
      return [] if source.to_s.empty?
      source.to_a.flatten
    end

    def render_hash(*args)
      return '' if @root.nil?

      context = case args.first
      when Liquid::Context
        args.shift
      when Hash
        Context.new([args.shift, assigns], instance_assigns, registers, @rethrow_errors)
      when nil
        Context.new(assigns, instance_assigns, registers, @rethrow_errors)
      else
        raise ArgumentError, "Expect Hash or Liquid::Context as parameter"
      end

      case args.last
      when Hash
        options = args.pop

        if options[:registers].is_a?(Hash)
          self.registers.merge!(options[:registers])
        end

        if options[:filters]
          context.add_filters(options[:filters])
        end

      when Module
        context.add_filters(args.pop)
      when Array
        context.add_filters(args.pop)
      end

      begin
        # render the nodelist.
        # for performance reasons we get a array back here. join will make a string out of it
        result = @root.render_hash(context)
        result.respond_to?(:join) ? result.join : result
      ensure
        @errors = context.errors
      end
    end
    
  end
end
