module Solution::ArticlesHelper
	ActionView::Base.default_form_builder = FormBuilders::RedactorBuilder
	
end
