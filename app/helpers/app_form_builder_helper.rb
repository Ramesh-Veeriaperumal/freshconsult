module AppFormBuilderHelper
  class AppFormBuilder < ActionView::Helpers::FormBuilder
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::FormTagHelper

    CODEMIRROR_DEFAULTS = {
      :lineNumbers => true,
      :mode      => "liquid", 
      :theme     => 'textmate',
      :tabMode   => "indent",
      :gutter    => true
    }

    def code_editor(method, options = {})     
      options[:id] = field_id( method, options[:index] )
      code_editor_tag(field_name(method), @object.send(method), options)
    end

    def code_editor_tag(name, content = nil, options = {})      
      id = options[:id] = options[:id] || field_id( name )
      if options[:height].present?
        set_height = "window.code_mirrors['#{id}'].getScrollerElement().style.height = '#{options[:height]}'"
      end

      _javascript_options = CODEMIRROR_DEFAULTS.merge(options).to_json

      output = <<HTML
#{text_area_tag(name, content, options)}
<script type="text/javascript">
if (window['code_mirrors'] === undefined) window.code_mirrors = {}
window.code_mirrors['#{id}'] = CodeMirror.fromTextArea(document.getElementById('#{id}'), #{_javascript_options})
#{set_height || ""}
window.code_mirrors['#{id}'].refresh()
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

# ActionView::Base.default_form_builder = AppFormBuilderHelper::AppFormBuilder