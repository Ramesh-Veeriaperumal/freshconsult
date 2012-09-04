class ThemeController < SupportController
	caches_page :index
	skip_before_filter :set_liquid_variables

	def index
		@theme_colors = @portal.preferences.map{ |k, p| (k != "logo_link") ? "$#{k}:#{p};" : "" }.join("")

		@default_custom_css = render_to_string(:file => "#{Rails.root}/public/src/portal/portal.scss")

		@custom_css = (@portal.template.present?) ? @portal.template.custom_css.to_s : ""

		_options = Compass.configuration.to_sass_engine_options.merge(:syntax => :scss, :always_update => true, :style => :compressed)
		_options[:load_paths] << "#{Rails.root}/public/src/portal"

		engine = Sass::Engine.new(@theme_colors + @default_custom_css + @custom_css, _options)

		@output_css = engine.render

		respond_to do |format|
		  format.css  { render :text => @output_css, :content_type => "text/css", :cache => true}
		end
	end

end