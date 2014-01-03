class Theme::SupportController < ThemeController
	
	skip_before_filter :check_privilege

	# Cache key for helpdesk file detecting change in file updated time
	THEME_URL 			= "#{RAILS_ROOT}/public/src/portal/portal.scss"
	THEME_TIMESTAMP 	= (File.exists?(THEME_URL) && File.mtime(THEME_URL).to_i)

	# Precautionary settings override
	THEME_ALLOWED_OPTS = %w( 	bg_color header_color tab_color tab_hover_color
								help_center_color footer_color btn_background btn_primary_background 
								baseFont baseFontFamily headingsFontFamily textColor headingsFont 
								headingsColor linkColor linkColorHover inputFocusRingColor nonResponsive )

	private

		def scoper
			# Compile using draft based on preview param
			(params[:preview].present? && current_portal.template.get_draft) ?
				current_portal.template.get_draft : current_portal.template
		end

		def theme_load_path
			@theme_load_path ||= "#{RAILS_ROOT}/public/src/portal"	
		end

end