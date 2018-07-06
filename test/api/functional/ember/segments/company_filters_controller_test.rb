require_relative '../../../test_helper'

module Ember
  module Segments
    class CompanyFiltersControllerTest < ActionController::TestCase

      include SegmentFiltersTestHelper
      include PrivilegesHelper


      def setup
        super
        @account = Account.first.make_current
        @account.add_feature(:segments)
      end

      def teardown
        super
      end

      def wrap_cname(params)
        { company_filter: params }
      end

      def filter_params
        COMPANY_FILTER_PARAMS
      end

      def updated_filter_params
        COMPANY_UPDATED_FILTER_PARAMS
      end

      def create_segment
        create_company_segment
      end

    end
  end
end