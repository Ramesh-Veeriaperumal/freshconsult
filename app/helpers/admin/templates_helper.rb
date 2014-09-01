module Admin::TemplatesHelper
	# Form builder used for including code_editor helper
	include FormBuilders
	# ActionView::Base.default_form_builder = FormBuilders::CodeMirrorBuilder
  
  def fullscreen_title title
    "<span class='light'>#{t("portalcss.editing")}</span> : #{title}"
  end
end
