class Theme::SupportRtlController < Theme::SupportController

	# Cache key for helpdesk file detecting change in file updated time
	THEME_URL          = "#{Rails.root}/public/src/rtl/portal/portal_rtl.scss"
	THEME_URL_PROXY    = "#{Rails.root}/public/src/portal/portal.scss"
	THEME_VERSION      = 'theme/spr/1'

	THEME_URL_FALCON          = "#{Rails.root}/public/src/rtl/portal/falcon_portal_rtl.scss"
	THEME_URL_PROXY_FALCON    = "#{Rails.root}/public/src/portal/falcon_portal.scss"
	THEME_VERSION_FALCON      = 'theme/fspr/1'

	private

		def theme_load_path
			@theme_load_path ||= "#{Rails.root}/public/src/rtl/portal"
		end
end
