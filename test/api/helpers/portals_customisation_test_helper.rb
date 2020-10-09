module PortalsCustomisationTestHelper
  def create_portal_with_customisation(params = {})
    test_portal = FactoryGirl.build(
      :portal,
      name: params[:portal_name] || Faker::Name.name,
      portal_url: params[:portal_url] || '',
      language: 'en',
      forum_category_ids: (params[:forum_category_ids] || ['']),
      solution_category_metum_ids: (params[:solution_category_metum_ids] || params[:solution_category_ids] || ['']),
      account_id: @account.id,
      preferences: preference_hash
    )
    test_portal.save(validate: false)
    test_portal
  end

  def portal_pattern(portal, _expected_output = {})
    portal_hash = {
      id: Fixnum,
      name: portal.name,
      host: portal.host,
      language: portal.language,
      default: portal.main_portal?,
      product_id: portal.product_id,
      ssl_enabled: portal.ssl_enabled?,
      solution_category_ids: portal.portal_solution_categories.pluck(:solution_category_meta_id),
      preferences: portal.preferences,
      helpdesk_logo: get_helpdesk_logo(portal),
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    portal_hash[:discussion_category_ids] = portal.portal_forum_categories.pluck(:forum_category_id) if forums_enabled?
    portal_hash[:fav_icon_url] = portal.fetch_fav_icon_url if portal.fav_icon
    portal_hash
  end

  def portal_show_pattern(portal, _expected_output = {})
    response_pattern = portal_pattern(portal, _expected_output)
  end

  def preference_hash
    header_color = format('#%06x', (rand * 0xffffff))
    tab_color = format('#%06x', (rand * 0xffffff))
    bg_color = format('#%06x', (rand * 0xffffff))
    primary_color = format('#%06x', (rand * 0xffffff))
    nav_color = format('#%06x', (rand * 0xffffff))
    preferences = { 
      header_color: header_color,
      tab_color: tab_color,
      bg_color: bg_color,
      helpdesk: { primary_background: primary_color, nav_background: nav_color } 
    }
  end

  def portal_hash(portal)
    portal_hash = {
      name: portal.name,
      host: portal.host,
      default: portal.main_portal?,
      product_id: portal.product_id,
      ssl_enabled: portal.ssl_enabled?,
      solution_category_ids: portal.portal_solution_categories.pluck(:solution_category_meta_id),
      preferences: portal.preferences,
      helpdesk_logo: get_helpdesk_logo(portal),
      created_at: portal.created_at,
      updated_at: portal.updated_at
    }
  end

  def get_helpdesk_logo(portal)
    portal_logo = portal.helpdesk_logo
    return nil if portal_logo.blank?
    helpdesk_logo = {
      id: portal_logo.id,
      name: portal_logo.content_file_name,
      content_type: portal_logo.content_content_type,
      size: portal_logo.content_file_size,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      attachment_url: String
    }
  end

  def forums_enabled?
    Account.current.features?(:forums) && !Account.current.hide_portal_forums_enabled?
  end
end
