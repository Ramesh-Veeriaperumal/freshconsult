module PortalTestHelper

  def central_publish_portal_pattern(portal)
    {
      id: portal.id,
      name: portal.name,
      product_id: portal.product_id,
      account_id: portal.account_id,
      portal_url: portal.portal_url,
      solution_category_id: portal.solution_category_id,
      forum_category_id: portal.forum_category_id,
      language: portal.language,
      main_portal: portal.main_portal,
      ssl_enabled: portal.ssl_enabled,
      created_at: portal.created_at.try(:utc).try(:iso8601),
      updated_at: portal.updated_at.try(:utc).try(:iso8601)
    }
  end

  def model_changes_for_central_pattern(portal_name_changes)
    {
      "name"=> portal_name_changes
    }
  end

  def central_publish_portal_destroy_pattern(portal)
    {
      id: portal.id,
      portal_url: portal.portal_url,
      account_id: portal.account_id
    }
  end

  def association_portal_pattern(portal)
    {
      product: (portal.product ? Hash : nil)
    }
  end
end