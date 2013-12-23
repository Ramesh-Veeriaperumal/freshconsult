module ThemeControllerMethods

	THEME_COMPASS_SETTINGS 	= { :syntax => :scss, 
								:always_update => true, 
								:style => :compressed }	

	private

		def set_http_cache_headers
			expires_in 10.years, :public => true
		end

		def render_scss
			_opts = Compass.configuration.to_sass_engine_options.merge(THEME_COMPASS_SETTINGS)
			_opts[:load_paths] << theme_load_path
			engine = Sass::Engine.new(theme_scss, _opts)
			engine.render
		end

		def theme_settings
			theme_allowed_settings.map { |k|
				settings_scoper[k].present? ? "$#{k}:#{settings_scoper[k]};" : ""
			}
		end

		def theme_template
			@theme_template ||= render_to_string(:file => theme_url)
		end

	protected

		def settings_scoper
			@settings_scoper ||= current_portal.preferences
		end

		def theme_scss
			puts "----> #{theme_settings}"
			%( #{theme_settings}
			   #{theme_template} )
		end

		def theme_load_path
			"#{RAILS_ROOT}/public/src/"
		end

end