class ThemeController < ApplicationController
	include Portal::PreviewKeyTemplate
	prepend_before_filter :set_http_cache_headers

	skip_before_filter :set_cache_buster
	caches_action :index, :cache_path => :cache_key, :if => :render_from_cache?

	

	THEME_COMPASS_SETTINGS 	= { :syntax => :scss, 
								:always_update => true, 
								:style => :compressed}	

	def index
		respond_to do |format|
		  	format.css  { render :text => compile_scss, :content_type => "text/css" }
		end
	end

	private

		def scoper_cache_key
			if defined?(self.class::THEME_VERSION_FALCON).present? && (current_account.falcon_support_portal_theme_enabled? ||  current_portal.falcon_portal_enable?)
				[self.class::THEME_VERSION_FALCON, scoper.id, scoper.updated_at.to_i].join("/") if(scoper.respond_to?(:updated_at))
			else
        		[self.class::THEME_VERSION, scoper.id, scoper.updated_at.to_i].join("/") if(scoper.respond_to?(:updated_at))
			end
		end

		def set_http_cache_headers
			expires_in 10.years, :public => true
		end

    def compile_scss(scss = scss_template)
      environment = orig_environment = ::Rails.application.assets
      environment = environment.instance_variable_get("@environment") if environment.is_a?(Sprockets::Index)
      context = environment.context_class.new(environment, '', Pathname.new(''))
      THEME_COMPASS_SETTINGS[:custom] = {:resolver => ::Sass::Rails::Resolver.new(context)}

			_opts = Compass.configuration.to_sass_engine_options.merge(THEME_COMPASS_SETTINGS)

			# Appending the theme load path as partial scss includes 
			# will be from the root src dir when reading from a file
			_opts[:load_paths] << theme_load_path
			_opts[:load_paths] << "#{Rails.root}/public/images"
     		_opts[:load_paths] << "#{Rails.root}/public/assets"	

			Sass::Engine.new(scss, _opts).render
	end
		
	protected

		def cache_key_url
			"#{scoper_cache_key}#{request.fullpath}"
		end

		def theme_load_path
			@theme_load_path ||= "#{Rails.root}/public/src"	
		end

		def render_from_cache?
			true
		end

		def scss_template
			

			_output = []
			# Getting settings from model pref
			_output << theme_settings(scoper.preferences) if(scoper.respond_to?(:preferences))
			# Appending Data from base css file 
			if (current_portal.falcon_portal_enable? || current_account.falcon_support_portal_theme_enabled? || on_mint_preview ) && defined?(self.class::THEME_URL_FALCON).present?
				_output << read_scss_file(self.class::THEME_URL_FALCON) if(File.exists?(self.class::THEME_URL_FALCON))
			else
				_output << read_scss_file(self.class::THEME_URL) if(File.exists?(self.class::THEME_URL))
			end

			# Appending custom css if it is a portal theme
			_output << custom_css if !on_mint_preview

			_output.join("")
		end	

		def theme_settings(settings)
			@theme_settings ||= self.class::THEME_ALLOWED_OPTS.map { |k|
				settings[k].present? ? "$#{k}:#{settings[k]};" : ""
			}
		end

		def read_scss_file(file_url)
			@theme_template ||= render_to_string(:file => file_url)
		end
		
		def custom_css
			scoper.custom_css if(feature?(:css_customization) && scoper.respond_to?(:custom_css))
		end
	end