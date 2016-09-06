module Ember
  class ContactFieldsController < ::ApiContactFieldsController
    private

      def resource
        # Hack to avoid adding additional entries at privileges.rb
        :api_contact_field
      end
  end
end
