module DoorkeeperExtension
  
  module DoorkeeperModelExtension
    extend ActiveSupport::Concern

    included do
      belongs_to_account

      before_create :clear_existing_records

      def clear_existing_records
        self.class.where(account_id: self.account_id,
          resource_owner_id: self.resource_owner_id,
          application_id: self.application_id).delete_all
      end

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

Doorkeeper::Application.send :include, DoorkeeperExtension::DoorkeeperApplicationModelExtension
Doorkeeper::AccessGrant.send :include, DoorkeeperExtension::DoorkeeperModelExtension
Doorkeeper::AccessToken.send :include, DoorkeeperExtension::DoorkeeperModelExtension
