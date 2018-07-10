module Ember
  module Segments
    class ContactFiltersController < BaseFiltersController
      private

        def scoper
          current_account.contact_filters
        end

        def current_filter
          :contact_filter
        end
    end
  end
end
