module FormBuilders::Redactor

      # !REDACTOR TODO need to keep a default settings options and then later modify based on other editor type
      # If possible move this to a lib settings file

      REDACTOR_FORUM_EDITOR = {
        :autoresize => false,
        :tabindex => 2,
        :convertDivs => false,
        :imageUpload => "/forums_uploaded_images",
        :clipboardImageUpload => "/forums_uploaded_images/create_file",
        :allowedTags => ["a", "div", "b", "i", "iframe", "br", "p", "img", "strong", "em" , "u", "span","pre"],
        :allowTagsInCodeSnippet => true,
        :buttons => ['bold','italic','underline', 'deleted','|','unorderedlist', 'orderedlist',  
                      '|','fontcolor', 'backcolor', '|' ,'link','image', 'video','codeEditor']
      }

      REDACTOR_SOLUTION_EDITOR = {
        :autoresize => true,
        :tabindex => 2,
        :convertDivs => false,
        :allowTagsInCodeSnippet => true,
        :imageUpload => "/solutions_uploaded_images",
        :clipboardImageUpload => "/solutions_uploaded_images/create_file",
        :imageGetJson => "/solutions_uploaded_images",
        :buttons => ['formatting','bold','italic','underline','deleted',
                        'unorderedlist', 'orderedlist','fontcolor', 'backcolor','insert_table']
      }

      REDACTOR_TICKET_EDITOR = {
        :focus => true,
        :autoresize => false,
        :tabindex => 2,
        :convertDivs => false,
        :allowTagsInCodeSnippet => true,
        :imageUpload => "/tickets_uploaded_images",
        :clipboardImageUpload => "/tickets_uploaded_images/create_file",
        :buttons => ['bold','italic','underline','|','unorderedlist', 'orderedlist',  
                      '|','fontcolor', 'backcolor', '|' ,'link', 'image']
      }

      REDACTOR_DEFAULT_EDITOR = {
        :focus => true,
        :autoresize => false,
        :tabindex => 2,
        :convertDivs => false,
        :setFontSettings => true,
        :buttons => ['bold','italic','underline','|','unorderedlist', 'orderedlist',  
                      '|','fontcolor', 'backcolor', '|' ,'link', 'removeFormat']
      }

      def rich_editor(method, options = {})
        options[:id] = options[:id] || field_id( method, options[:index] )  
        rich_editor_tag(field_name(method), @object.send(method), options).html_safe
      end

      def rich_editor_tag(name, content = nil, options = {})
        id = options[:id] = options[:id] || field_id( name )
        content = options[:value] unless options[:value].nil?

        redactor_opts = redactor_type options['editor-type']

        _javascript_options = redactor_opts.merge(options).to_json

        # Height set as :height in the redator helper object will be used as the base height for the js editor
        options[:style] = "height:#{options[:height]};" if options[:height]
        options[:rel] = "redactor"
        options[:class] = "redactor-textarea #{options[:class]}" 

        output = []
        output << text_area_tag(name, content, options)

        output << %(<script type="text/javascript">
                      if( !isMobile.any() ){
                        if (window['redactors'] === undefined) window.redactors = {}
                        !function( $ ) {
                          $(function() {
                            window.redactors['#{id}'] = $('##{id}').redactor(#{_javascript_options})
                          })  
                        }(window.jQuery);
                      }
                  </script>)

        output.join('')  
      end

      def redactor_type _type
        case _type
          when :solution then
            REDACTOR_SOLUTION_EDITOR
          when :forum then
            REDACTOR_FORUM_EDITOR
          when :ticket then
            REDACTOR_TICKET_EDITOR
          else
            REDACTOR_DEFAULT_EDITOR
        end
      end

end