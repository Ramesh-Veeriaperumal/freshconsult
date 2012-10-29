module FormBuilders
  class RedactorBuilder < ActionView::Helpers::FormBuilder
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::FormTagHelper

      REDACTOR_FORUM_EDITOR = {
        :autoresize => false,
        :tabindex => 2,
        :convertDivs => false,
        :imageUpload => "/uploaded_images",
        :allowedTags => ["a", "div", "b", "i"],
        :buttons => ['bold','italic','underline','|','unorderedlist', 'orderedlist',  '|','fontcolor', 'backcolor', '|' ,'link','image', 'video']
      }

      def rich_editor(method, options = {})     
        options[:id] = field_id( method, options[:index] )  
        rich_editor_tag(field_name(method), @object.send(method), options)
      end

      def rich_editor_tag(name, content = nil, options = {})
        id = options[:id] = options[:id] || field_id( name )          
        content = options[:value] if options[:value].present?

        _javascript_options = REDACTOR_FORUM_EDITOR.merge(options).to_json

        # Height set as :height in the redator helper object will be used as the base height for the js editor
        options[:style] = "height:#{options[:height]}px;"

        output = <<HTML
#{text_area_tag(name, content, options)}
<script type="text/javascript">
    if (window['redactors'] === undefined) window.redactors = {}
    !function( $ ) {
      $(function() {
        window.redactors['#{id}'] = $('##{id}').redactor(#{_javascript_options})
      })  
    }(window.jQuery);
</script>
HTML
        output.html_safe  
      end

      def field_name(label, index = nil)
        @object_name.to_s + ( index ? "[#{index}]" : '' ) + "[#{label}]"
      end

      def field_id(label, index = nil)
        @object_name.to_s + ( index ? "_#{index}" : '' ) + "_#{label}"
      end

  end
end