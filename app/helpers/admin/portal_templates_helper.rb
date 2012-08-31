module Admin::PortalTemplatesHelper
	# Form builder used for including code_editor helper
	include FormBuilders
	ActionView::Base.default_form_builder = FormBuilders::CodeMirrorBuilder
end
