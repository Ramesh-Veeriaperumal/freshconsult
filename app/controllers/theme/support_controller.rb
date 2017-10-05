class Theme::SupportController < ThemeController
	
	skip_before_filter :check_privilege, :verify_authenticity_token

	# Cache key for helpdesk file detecting change in file updated time
	
	THEME_URL 			= "#{Rails.root}/public/src/portal/portal.scss"
	THEME_TIMESTAMP 	= (File.exists?(THEME_URL) && File.mtime(THEME_URL).to_i)

	THEME_URL_FALCON 		= "#{Rails.root}/public/src/portal/falcon_portal.scss"
	THEME_TIMESTAMP_FALCON 	= (File.exists?(THEME_URL_FALCON) && File.mtime(THEME_URL_FALCON).to_i)

	# Precautionary settings override
	THEME_ALLOWED_OPTS = %w( 	bg_color header_color tab_color tab_hover_color
								help_center_color footer_color btn_background btn_primary_background 
								baseFont baseFontFamily headingsFontFamily textColor headingsFont 
								headingsColor linkColor linkColorHover inputFocusRingColor nonResponsive )

	private

		def scoper			
			template = current_portal.template
			# Compile draft based on preview param
			template = current_portal.template.get_draft if(params[:preview].present? && current_portal.template.get_draft)
			template
		end

		def theme_load_path
			@theme_load_path ||= "#{Rails.root}/public/src/portal"	
		end

		# Don't cache the preview as it may be different for various people
		def render_from_cache?
			params[:preview].blank?
		end

end