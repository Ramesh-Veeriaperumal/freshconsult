class WhitelistedIp < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :vault_service do |b|
    b.add :ip_ranges
    b.add :enabled_for_customers
    b.add :enabled
  end

  def enabled_for_customers
    !applies_only_to_agents
  end
end
