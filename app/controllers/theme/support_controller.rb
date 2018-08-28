class Theme::SupportController < ThemeController
  include Portal::ColourConstants
  include Portal::PreviewKeyTemplate
	skip_before_filter :check_privilege, :verify_authenticity_token

# Cache key for helpdesk file detecting change in file updated time
  THEME_URL       = "#{Rails.root}/public/src/portal/portal.scss"
  THEME_VERSION   = 'theme/sp/1'

  THEME_URL_FALCON       = "#{Rails.root}/public/src/portal/falcon_portal.scss"
  THEME_VERSION_FALCON   = 'theme/fsp/1'

# Precautionary settings override
THEME_ALLOWED_OPTS = %w( bg_color header_color tab_color tab_hover_color
                        help_center_color footer_color btn_background btn_primary_background 
                        baseFont baseFontFamily headingsFontFamily textColor headingsFont 
                        headingsColor linkColor linkColorHover inputFocusRingColor nonResponsive )

private
  def scoper
      template = current_portal.template
      falcon_portal_enable = current_portal.preferences.key?(:falcon_portal_key)
      if on_mint_preview && params[:preview].present? && !falcon_portal_enable
        template = template.get_draft if template.get_draft 
        current_preferences = template.preferences.symbolize_keys
        template.preferences = FALCON_COLOURS.merge(current_preferences.diff(OLD_COLOURS))
      elsif params[:preview].present? && template.get_draft
        template = template.get_draft
      end
      template.preferences = template.preferences.stringify_keys
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