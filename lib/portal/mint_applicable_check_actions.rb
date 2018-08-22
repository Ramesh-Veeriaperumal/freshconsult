module Portal::MintApplicableCheckActions
  def support_mint_applicable?
    if !current_account.falcon_portal_theme_enabled? && current_account.launched?(:mint_portal_applicable)
      portals = current_account.portals
      portals.any? do |current_portal|
        current_template = current_portal.template
        !current_portal.falcon_portal_enable? && current_template.header.blank? && current_template.footer.blank? &&  current_template.custom_css.blank? && current_template.layout.blank? && current_template.pages.size == 0
      end
    end
  end

  def support_mint_applicable_portal?(current_portal) 
    if !current_account.falcon_portal_theme_enabled? && current_account.launched?(:mint_portal_applicable)    
      current_template = current_portal.template
      !current_portal.falcon_portal_enable? && current_template.header.blank? && current_template.footer.blank? &&  current_template.custom_css.blank? && current_template.layout.blank? && current_template.pages.size == 0
    end
  end
end