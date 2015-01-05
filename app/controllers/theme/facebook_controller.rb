class Theme::FacebookController < Theme::SupportController
  
  skip_before_filter :check_privilege, :verify_authenticity_token

  # Cache key for helpdesk file detecting change in file updated time
  THEME_URL       = "#{Rails.root}/public/src/portal/facebook.scss"
  THEME_TIMESTAMP   = (File.exists?(THEME_URL) && File.mtime(THEME_URL).to_i)

  # Precautionary settings override
  THEME_ALLOWED_OPTS = %w(  bg_color header_color tab_color tab_hover_color
                help_center_color footer_color btn_background btn_primary_background 
                baseFont baseFontFamily headingsFontFamily textColor headingsFont 
                headingsColor linkColor linkColorHover inputFocusRingColor nonResponsive )

  private
  
    def custom_css
      nil
    end

end

