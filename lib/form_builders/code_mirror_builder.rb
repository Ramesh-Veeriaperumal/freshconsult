module FormBuilders
  class CodeMirrorBuilder < ActionView::Helpers::FormBuilder
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::FormTagHelper

    CODEMIRROR_DEFAULTS = {
    }

    def code_editor(method, options = {})     
      options[:id] = field_id( method, options[:index] )  
      code_editor_tag(field_name(method), @object.send(method), options)
    end

    def code_editor_tag(name, content = nil, options = {})      
      id = options[:id] = options[:id] || field_id( name )

      content = options[:value] if options[:value].present?

      _javascript_options = CODEMIRROR_DEFAULTS.merge(options)

      output = []
      # Returning a text area with codemirror details
      output << %( #{text_area_tag(name, content, options)} )
      # jQuery function call to wrap the codemirror editor 
      output << %( <script type="text/javascript"> )
      output << %( jQuery("##{id}").codemirror(#{_javascript_options.to_json}) )
      output << %( </script> )

      output.join(' ')
    end

    def field_name(label, index = nil)
      @object_name.to_s + ( index ? "[#{index}]" : '' ) + "[#{label}]"
    end

    def field_id(label, index = nil)
      @object_name.to_s + ( index ? "_#{index}" : '' ) + "_#{label}"
    end

  end
end