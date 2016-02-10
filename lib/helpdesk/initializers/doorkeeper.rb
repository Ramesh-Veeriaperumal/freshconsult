module Doorkeeper
  module DoorkeeperModelExtension
    extend ActiveSupport::Concern
    included do
      belongs_to_account
    end
  end

  module DoorkeeperApplicationModelExtension
    extend ActiveSupport::Concern
    included do
      belongs_to :account
      belongs_to :user
    end
  end
end

Doorkeeper::Application.send :include, Doorkeeper::DoorkeeperApplicationModelExtension
Doorkeeper::AccessGrant.send :include, Doorkeeper::DoorkeeperModelExtension
Doorkeeper::AccessToken.send :include, Doorkeeper::DoorkeeperModelExtension
