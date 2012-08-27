module Admin::PortalTemplatesHelper
	
	class AppFormBuilder < ActionView::Helpers::FormBuilder
		include ActionView::Helpers::TagHelper
		include ActionView::Helpers::FormTagHelper		

		def ace_editor(method, options = {})			
			options[:id] = field_id( method, options[:index] )
			options[:class] = " ace-editor"

			ace_editor_tag(field_name(method), @object.send(method), options)
		end

		def ace_editor_tag(name, content = nil, options = {})			
          	_form_control = text_area_tag(name, content, :class => "hide")
          	_control_id = options[:id]
          	mode  	  = options[:mode] || 'liquid'
          	theme 	  = options[:theme] || 'textmate' # nil => default theme

          	mode_class = "#{mode}_mode".camelize
		  	id = options[:id] = "#{( options[:id] || field_id( name ) )}_ace"
			theme_setter = theme ? "window.ace_editors['#{id}'].setTheme('ace/theme/#{theme}');" : ""
			_style = "height: #{options[:height] || '400px'}"
			
			pre_tag = content_tag(:pre, h(content), options)

			_div_options = { :class => "ace-editor", 
							 :rel => "ace-editor", 
							 "data-form-id" => _control_id,
							 "data-ace-id" => id,
							 :style => _style }
							 
			ace_container = content_tag :div, _form_control + pre_tag, _div_options 
		  	
		  	output = <<HTML
#{ace_container}
<script type='text/javascript'>
  jQuery(function(){
    if (window['ace_editors'] === undefined) window.ace_editors = {};
    window.ace_editors['#{id}'] = ace.edit('#{id}');
    #{theme_setter}
    var #{mode_class} = ace.require("ace/mode/#{mode}").Mode;
    window.ace_editors['#{id}'].getSession().setMode(new #{mode_class}());

    window.ace_editors['#{id}'].on("blur", function(e){
		document.getElementById('#{_control_id}').value = window.ace_editors['#{id}'].getSession().getValue();
	})
  });
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
