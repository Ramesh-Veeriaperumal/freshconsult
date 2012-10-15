class ThemeController < SupportController
	include RedisKeys

	caches_page :index
	skip_before_filter :set_liquid_variables

	def index
		@theme_colors = @portal.preferences.map{ |k, p| (k != "logo_link") ? "$#{k}:#{p};" : "" }.join("")

		@default_custom_css = render_to_string(:file => "#{RAILS_ROOT}/public/src/portal/portal.scss")
		if (!params[:preview].blank? && !current_user.blank?)
			key = redis_key(":custom_css", current_portal.template[:id])
			@custom_css = exists(key) ? get_key(key) : @portal.template.custom_css.to_s
		else
			@custom_css = (@portal.template.present?) ? @portal.template.custom_css.to_s : ""
		end

		_options = Compass.configuration.to_sass_engine_options.merge(:syntax => :scss, :always_update => true, :style => :compressed)
		_options[:load_paths] << "#{RAILS_ROOT}/public/src/portal"

		engine = Sass::Engine.new(@theme_colors + @default_custom_css + @custom_css, _options)

		@output_css = engine.render

		respond_to do |format|
		  format.css  { render :text => @output_css, :content_type => "text/css", :cache => true}
		end
	end

	private

		def redis_key label, template_id
      PORTAL_PREVIEW % {:account_id => current_account.id, 
                        :label=> label, 
                        :template_id=> template_id, 
                        :user_id => current_user.id
                      }
    end

end