# frozen_string_literal: true

module Admin
  class GroupsController < Ember::GroupsController
    decorate_views

    private

      def validate_filter_params
        params.permit(*GROUP_V2_INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
        ParamsHelper.assign_and_clean_params({ type: :group_type }, params)
        @group_filter = GroupFilterValidation.new(params)
        render_errors(@group_filter.errors, @group_filter.error_options) unless @group_filter.valid?
      end

      def launch_party_name
        FeatureConstants::GROUP_MANAGEMENT_V2
      end
  end
end
