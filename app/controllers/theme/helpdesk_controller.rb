class Theme::HelpdeskController < ThemeController

	skip_before_filter :check_privilege, :verify_authenticity_token

    # Cache key for helpdesk file detecting change in file updated time
	THEME_URL 			= "#{Rails.root}/public/src/helpdesk-theme.scss"
	THEME_TIMESTAMP 	= (File.exists?(THEME_URL) && File.mtime(THEME_URL).to_i)

	# Precautionary settings override
	THEME_ALLOWED_OPTS	= %w( bg_color header_color tab_color )

	private

		def scoper
			current_portal
		end

end