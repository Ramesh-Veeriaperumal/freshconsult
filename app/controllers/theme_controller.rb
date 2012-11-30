class ThemeController < SupportController
	include RedisKeys

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
		@portal.build_template.save if @portal.template.blank? 
		_options = Compass.configuration.to_sass_engine_options.merge(:syntax => :scss, :always_update => true, :style => :compact)
		_options[:load_paths] << "#{RAILS_ROOT}/public/src/portal"

		engine = Sass::Engine.new("#{@theme_colors} #{@default_custom_css}", _options)

		@output_css = engine.render

		respond_to do |format|
		  format.css  { render :text => @output_css, :content_type => "text/css" }
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

    def get_preferences
    	unless session[:preview_button].blank?
    		rkey = redis_key(:preferences,@portal.template.id)
				rdata = get_key(rkey)
				rdata = JSON.parse(rdata) unless rdata.blank?
    	end
    	rdata || @portal.template.preferences || []
    end

    def get_custom_scss
    	unless session[:preview_button].blank?
	    	rkey = redis_key(:custom_css,@portal.template.id)
				rdata = get_key(rkey)
			end
			rdata || @portal.template.custom_css.to_s || ""
    end

    def set_theme_colors
    	@theme_colors = get_preferences.map{ |k, p| (ALLOWED_THEME_OPTIONS.include? k.to_s) ? "$#{k}:#{p};" : "" }.join("")
    end

    def set_custom_scss	
    	@default_custom_css = render_to_string(:file => "#{RAILS_ROOT}/public/src/portal/portal.scss")
    	@default_custom_css = "#{@default_custom_css}\r\n #{get_custom_scss}"
    end

end