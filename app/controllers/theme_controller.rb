class ThemeController < SupportController

	caches_page :index
	skip_before_filter :set_liquid_variables
	before_filter :set_theme_colors, :set_custom_scss

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
		def preview?
      !session[:preview_button].blank? && !current_user.blank? && current_user.agent?
    end

    def get_preferences
    	preferences = @portal.template.preferences
    	preferences = @portal.template.get_draft.preferences if  preview? && @portal.template.get_draft
    	preferences || []
    end

    def get_custom_scss
    	return "" unless feature?(:css_customization)
    	custom_css = @portal.template.custom_css.to_s
			custom_css = @portal.template.get_draft.custom_css.to_s if  preview? && @portal.template.get_draft
			custom_css || ""
    end

    def set_theme_colors
    	@theme_colors = get_preferences.map{ |k, p| (ALLOWED_THEME_OPTIONS.include? k.to_s) ? "$#{k}:#{p};" : "" }.join("")
    end

    def set_custom_scss	
    	@default_custom_css = render_to_string(:file => "#{RAILS_ROOT}/public/src/portal/portal.scss")
    	@default_custom_css = "#{@default_custom_css}\r\n #{get_custom_scss}"
    end

end