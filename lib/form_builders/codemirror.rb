module FormBuilders::Codemirror

      CODEMIRROR_DEFAULTS = {
      }

      def code_editor(method, options = {})   
        options[:id] = field_id( method, options[:index] )  
        code_editor_tag(field_name(method), @object.send(method), options).html_safe
      end

      def code_editor_tag(name, content = nil, options = {})      
        id = options[:id] = options[:id] || field_id( name )

        content = options[:value] if options[:value].present?

        _javascript_options = CODEMIRROR_DEFAULTS.merge(options)


        output = []
        # Returning a text area with codemirror details
        output << %( #{text_area_tag(name, content, options)} )
        # jQuery function call to wrap the codemirror editor 
        _javascript_options =_javascript_options.except!(:value)
        output << %(<script type="text/javascript">
           jQuery("##{id}").data('codemirrorOptions',#{_javascript_options.to_json});
           jQuery("##{id}").attr('rel','codemirror');
           Fjax.Assets.plugin('codemirror');
          </script>
        )

        output.join(' ').html_safe
      end

end
