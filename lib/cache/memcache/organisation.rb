module Cache::Memcache::Organisation
  include MemcacheKeys
  FRESHWORK_PRODUCTS_URL = 'https://%{domain}/api/v2/products'.freeze

  def product_details_from_cache(organisation_domain)
    fetch_from_cache(FRESHWORK_PRODUCTS) do
      products = RestClient.safe_send(:get, format(FRESHWORK_PRODUCTS_URL, domain: organisation_domain))
      products = JSON.parse(products) if products
      products
    end
  end
end
