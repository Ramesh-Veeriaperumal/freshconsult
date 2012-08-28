module Admin::PortalTemplatesHelper
	
	class AppFormBuilder < ActionView::Helpers::FormBuilder
		include ActionView::Helpers::TagHelper
		include ActionView::Helpers::FormTagHelper		

		def code_editor(method, options = {})			
			options[:id] = field_id( method, options[:index] )
			code_editor_tag(field_name(method), @object.send(method), options)
		end

		def code_editor_tag(name, content = nil, options = {})			
			id = options[:id] = options[:id] || field_id( name )
			output = <<HTML
#{text_area_tag(name, content, options)}
<script type="text/javascript">
	if (window['code_mirrors'] === undefined) window.code_mirrors = {};
	window.code_mirrors['#{id}'] = CodeMirror.fromTextArea(document.getElementById('#{id}'), {
		lineNumbers: true,
		mode: "liquid", 
		theme: 'textmate',
		tabMode: "indent",
		onCursorActivity: function() {   
		 	var editor = window.code_mirrors['#{id}'];
			editor.setLineClass(hlLine, null, null);
			editor.matchHighlight("CodeMirror-matchhighlight");
			hlLine = editor.setLineClass(editor.getCursor().line, null, "activeline");  
		}
	});
	var hlLine = window.code_mirrors['#{id}'].setLineClass(0, "activeline");
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
