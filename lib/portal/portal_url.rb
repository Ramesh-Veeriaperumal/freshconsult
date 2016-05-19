module Portal::PortalUrl

  def portal_url_from_id portal_id = 0, account = Account.current 
    portal = (portal_id != 0) ? Portal.find_by_id(portal_id) : account.main_portal
    fetch_portal_full_url portal
  end

  def fetch_portal_full_url portal
    protocol  = portal.ssl_enabled? ? 'https://' : 'http://'
    port = (Rails.env.development? ? ":#{request.port}" : '')
    portal_url = protocol + portal.host + port
    portal_url
  end

end