module Ember
  module Segments
    class CompanyFiltersController < BaseFiltersController
      private

        def scoper
          current_account.company_filters
        end

        def current_filter
          :company_filter
        end
    end
  end
end
