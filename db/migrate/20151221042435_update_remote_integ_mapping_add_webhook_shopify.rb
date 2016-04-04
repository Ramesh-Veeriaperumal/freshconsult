class UpdateRemoteIntegMappingAddWebhookShopify < ActiveRecord::Migration

  shard :all

  def up
    application = Integrations::Application.find_by_name('shopify')
    Integrations::InstalledApplication.where(:application_id => application.id).all.each do |inst_app|
      begin
        url = "https://#{inst_app.configs_shop_name}/admin/webhooks.json"
        webhook_verifier = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, inst_app.configs_shop_name, Time.now.to_i.to_s)
        payload = {"webhook" => {
          "topic" => 'app/uninstalled',
          "address" => "#{Account.find(inst_app.account_id).full_url}/integrations/marketplace/shopify/receive_webhook?webhook_verifier=#{webhook_verifier}",
          "format" => "json"
        }}
        http_resp = HTTParty.post(url, { :body => payload, :headers => { "X-Shopify-Access-Token"=> inst_app.configs_oauth_token } })

        if http_resp.code == 201
          remote_integ_map = Integrations::ShopifyRemoteUser.where(:remote_id => inst_app.configs_shop_name).first
          if remote_integ_map.nil?
            Integrations::ShopifyRemoteUser.create(:account_id => inst_app.account_id, :remote_id => inst_app.configs_shop_name)
          end
          inst_app.configs[:inputs]["webhook_verifier"] = webhook_verifier
          inst_app.save
        elsif http_resp.code == 401 || http_resp.code == 402
          inst_app.destroy
        end
      rescue => e
        Rails.logger.error "\n#{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end

  def down
    Integrations::ShopifyRemoteUser.delete_all
  end
end
