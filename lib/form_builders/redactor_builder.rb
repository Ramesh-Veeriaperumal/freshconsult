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
        :allowedTags => ["a", "div", "b", "i"],
        :imageGetJson => "/uploaded_images",
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

      def rich_editor(method, options = {})
        options[:id] = field_id( method, options[:index] )  
        rich_editor_tag(field_name(method), @object.send(method), options)
      end

      def rich_editor_tag(name, content = nil, options = {})
        id = options[:id] = options[:id] || field_id( name )
        content = options[:value] if options[:value].present?

        redactor_opts = (options['editor-type'] == :solution) ? REDACTOR_SOLUTION_EDITOR : REDACTOR_FORUM_EDITOR

        _javascript_options = redactor_opts.merge(options).to_json

        # Height set as :height in the redator helper object will be used as the base height for the js editor
        options[:style] = "height:#{options[:height]}px;" if options[:height]
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

  end
end