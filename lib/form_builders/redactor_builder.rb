module FormBuilders
  class RedactorBuilder < ActionView::Helpers::FormBuilder
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::FormTagHelper

      # !REDACTOR TODO need to keep a default settings options and then later modify based on other editor type
      # If possible move this to a lib settings file

      REDACTOR_FORUM_EDITOR = {
        :autoresize => false,
        :tabindex => 2,
        :convertDivs => false,
        :imageUpload => "/uploaded_images",
        :allowedTags => ["a", "div", "b", "i", "iframe", "br", "p", "img", "strong", "em"],
        :buttons => ['bold','italic','underline', 'deleted','|','unorderedlist', 'orderedlist',  
                      '|','fontcolor', 'backcolor', '|' ,'link','image', 'video']
      }

      REDACTOR_SOLUTION_EDITOR = {
        :autoresize => false,
        :tabindex => 2,
        :convertDivs => false,
        :imageUpload => "/uploaded_images",
        :imageGetJson => "/uploaded_images"
      }

      REDACTOR_TICKET_EDITOR = {
        :focus => true,
        :autoresize => false,
        :tabindex => 2,
        :convertDivs => false,
        :buttons => ['bold','italic','underline','|','unorderedlist', 'orderedlist',  
                      '|','fontcolor', 'backcolor', '|' ,'link']
      }

      REDACTOR_DEFAULT_EDITOR = {
        :focus => true,
        :autoresize => false,
        :tabindex => 2,
        :convertDivs => false,
        :buttons => ['bold','italic','underline','|','unorderedlist', 'orderedlist',  
                      '|','fontcolor', 'backcolor', '|' ,'link']
      }

      def rich_editor(method, options = {})
        options[:id] = options[:id] || field_id( method, options[:index] )  
        rich_editor_tag(field_name(method), @object.send(method), options)
      end

      def rich_editor_tag(name, content = nil, options = {})
        id = options[:id] = options[:id] || field_id( name )
        content = options[:value] if options[:value].present?

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

      def field_name(label, index = nil)
        @object_name.to_s + ( index ? "[#{index}]" : '' ) + "[#{label}]"
      end

      def field_id(label, index = nil)
        @object_name.to_s + ( index ? "_#{index}" : '' ) + "_#{label}"
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
end