module PortalsTestHelper
  def portal_pattern(portal)
    portal_hash = {
      id: Fixnum,
      name: portal.portal_name,
      host: portal.host,
      default: portal.main_portal?,
      product_id: portal.product_id,
      ssl_enabled: portal.ssl_enabled?,
      solution_category_ids: portal.portal_solution_categories.pluck(:solution_category_meta_id),
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    portal_hash[:discussion_category_ids] = portal.portal_forum_categories.pluck(:forum_category_id) if forums_enabled?
    portal_hash[:fav_icon_url] = portal.fetch_fav_icon_url if portal.fav_icon
    portal_hash
  end

  def bot_prerequisites_pattern(portal)
    {
      tickets_count: portal.account.tickets.count(:id),
      articles_count: portal.bot_article_meta.count(:id)
    }
  end

  def forums_enabled?
    Account.current.features?(:forums) && !Account.current.hide_portal_forums_enabled?
  end
end
