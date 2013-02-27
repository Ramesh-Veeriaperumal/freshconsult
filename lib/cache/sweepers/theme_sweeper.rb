class Cache::Sweepers::ThemeSweeper < ActionController::Caching::Sweeper
	observe Portal::Template

	def after_update(template)
		expire_page("/theme/#{template.id}.css")
	end

	def after_templates_update
		template = assigns(:portal_template)
		expire_page("/theme/#{template.id}-#{current_user.id}-preview.css")
	end
end