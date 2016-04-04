class Ecommerce::EbayRemoteUser < RemoteIntegrationsMapping
  validates :remote_id, presence: true, uniqueness: true
end