class Reports::FreshvisualConfigs
  include Sidekiq::Worker
  include Reports::Pricing::Api

  sidekiq_options queue: :freshvisual_configs, retry: 0,  failures: :exhausted

  def perform(_args = {})
    create_tenant
    update_restrictions
  end
end
