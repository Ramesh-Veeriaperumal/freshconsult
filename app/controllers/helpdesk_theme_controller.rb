class HelpdeskThemeController < ApplicationController	
	include ThemeControllerMethods

	skip_before_filter :check_privilege
	prepend_before_filter :set_http_cache_headers
	caches_action :index, :cache_path => :cache_key
	

    # Cache key for helpdesk file detecting change in file updated time
	HELPDESK_THEME_URL 			= "#{RAILS_ROOT}/public/src/helpdesk-theme.scss"
	HELPDESK_THEME_TIMESTAMP 	= (File.exists?(HELPDESK_THEME_URL) && File.mtime(HELPDESK_THEME_URL).to_i)

	HELPDESK_THEME_ALLOWED_OPTS	= %w( bg_color header_color tab_color )

	def index
		respond_to do |format|
		  	format.css  { render :text => render_scss, :content_type => "text/css" }
		end
	end

	private
		def cache_key_url
			[HELPDESK_THEME_TIMESTAMP, current_portal.updated_at.to_i, current_portal.id, request.request_uri].join("/")
		end
	
		def theme_url
			@theme_url ||= HELPDESK_THEME_URL
		end

		def theme_allowed_settings
			@theme_allowed_settings ||= HELPDESK_THEME_ALLOWED_OPTS			
		end

end