class Integrations::ShopifyUtil

  def remove_remote_integrations_mapping(installed_app)
    begin
      remove_from_shopify(installed_app)
    rescue => e
      Rails.logger.error "Problem in removing app from shopify marketplace"
    end

    begin
      remote_integ_map = Integrations::ShopifyRemoteUser.where(:account_id => installed_app.account_id, :remote_id => installed_app.configs_shop_name).first
      unless remote_integ_map.nil?
        remote_integ_map.destroy
      end
    rescue => e
      Rails.logger.error "Problem in removing remote_integrations_mapping"
    end
  end

  def update_remote_integrations_mapping(installed_app)
    begin
      add_new_webhook(installed_app)
    rescue => e
      Rails.logger.error "Problem in adding webhook in Shopify."
    end

    begin
      remote_integ_map = Integrations::ShopifyRemoteUser.where(:account_id => installed_app.account_id).first
      if remote_integ_map.present?
        remote_integ_map.remote_id = installed_app.configs_shop_name
        remote_integ_map.save
      else
        Integrations::ShopifyRemoteUser.create!(:account_id => installed_app.account_id, :remote_id => installed_app.configs_shop_name)
      end
    rescue => e
      Rails.logger.error "Problem in updating remote_integrations_mapping"
    end
  end

  def remove_from_shopify(installed_app)
    revoke_url   = "https://#{installed_app.configs_shop_name}/admin/oauth/revoke"
    headers = { 'X-Shopify-Access-Token' => installed_app.configs_oauth_token, "content_type" => "application/json", "accept" => "application/json" }
    
    HTTParty.delete(revoke_url, {:headers => headers})
  end

  def add_new_webhook(installed_app)
    url = "https://#{installed_app.configs_shop_name}/admin/webhooks.json"
    headers = { 'X-Shopify-Access-Token' => installed_app.configs_oauth_token, "content_type" => "application/json", "accept" => "application/json" }
    webhook_verifier = installed_app.configs[:inputs]["webhook_verifier"]
    payload = {"webhook" => {
      "topic" => 'app/uninstalled',
      "address" => "#{Account.find(installed_app.account_id).full_url}/integrations/marketplace/shopify/receive_webhook?webhook_verifier=#{webhook_verifier}",
      "format" => "json"
    }}
    HTTParty.post(url, {:body => payload, :headers => headers})
  end

end
