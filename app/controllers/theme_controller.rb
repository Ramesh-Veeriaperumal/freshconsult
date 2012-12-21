class ThemeController < SupportController

	# caches_page :index
	before_filter :theme_colors, :merged_scss

	# Precautionary settings override
	ALLOWED_THEME_OPTIONS = %w( bg_color header_color help_center_color footer_color 
								tab_color tab_hover_color
								btn_background btn_primary_background 
								baseFontFamily textColor headingsFontFamily headingsColor
								linkColor linkColorHover inputFocusRingColor)

	def index		
		_options = Compass.configuration.to_sass_engine_options.merge(:syntax => :scss, :always_update => true, :style => :compact)
		_options[:load_paths] << "#{RAILS_ROOT}/public/src/portal"

		engine = Sass::Engine.new("#{@theme_colors} #{@default_custom_css}", _options)

		@output_css = engine.render

		respond_to do |format|
		  format.css  { render :text => @output_css, :content_type => "text/css" }
		end
	end

	private

    	def theme_colors
	    	@theme_colors = color_preferences.map{ |k, p| (ALLOWED_THEME_OPTIONS.include? k.to_s) ? "$#{k}:#{p};" : "" }.join("")
	    end

	    def color_preferences
	    	preferences = current_portal.template.preferences
	    	preferences = current_portal.template.get_draft.preferences if preview? && current_portal.template.get_draft
	    	preferences || []
	    end

	    def merged_scss	
	    	@default_custom_css = render_to_string(:file => "#{RAILS_ROOT}/public/src/portal/portal.scss")
	    	@default_custom_css = "#{@default_custom_css}\r\n #{custom_scss}"
	    end	    

	    def custom_scss
	    	return "" unless feature?(:css_customization)
	    	custom_css = current_portal.template.custom_css.to_s
			custom_css = current_portal.template.get_draft.custom_css.to_s if preview? && current_portal.template.get_draft
			custom_css || ""
	    end

end