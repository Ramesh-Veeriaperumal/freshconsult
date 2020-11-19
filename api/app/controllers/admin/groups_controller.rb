# frozen_string_literal: true

module Admin
  class GroupsController < Ember::GroupsController
    skip_before_filter :prepare_agents, only: [:create, :update]
    skip_before_filter :check_if_group_exists, only: [:create, :update] # override error message

    def create
      validate_and_save do
        @item.save ? render_201_with_location : render_errors(@item.errors)
      end
    end

    def update
      @item.assign_attributes(params[cname])
      validate_and_save do
        render_errors(@item.errors) unless @item.update_attributes(params[cname])
      end
    end

    def show
      if Account.current.omni_groups?
        render_errors(@item.errors) unless @item.find_freshid_usergroup_by_id
      end
    end

    private

      def validate_and_save
        assign_uniqueness_validated
        group_delegator = delegator_klass.new(@item, cname_params)
        if group_delegator.valid?(action_name.to_sym)
          build_attributes
          yield
        else
          render_errors(group_delegator.errors, group_delegator.error_options)
        end
      end

      def validate_filter_params
        params.permit(*GROUP_V2_INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
        ParamsHelper.assign_and_clean_params({ type: :group_type }, params)
        @group_filter = GroupFilterValidation.new(params)
        render_errors(@group_filter.errors, @group_filter.error_options) unless @group_filter.valid?
      end

      def launch_party_name
        FeatureConstants::GROUP_MANAGEMENT_V2
      end

      def validate_params
        group_params = (fetch_group_params - GROUP_V2_NEGATE_FIELDS | GROUP_V2_CREATE_FIELDS).uniq
        group_params = update? ? group_params - %w[type] : group_params
        params[cname].permit(*group_params)
        before_validate_params
        validator = validation_klass.new(cname_params, @item)
        render_custom_errors(validator, true) unless validator.valid?(action_name.to_sym)
      end

      def sanitize_params
        ParamsHelper.assign_and_clean_params({ type: :group_type }, params[cname])
        super
      end

      def validation_klass
        @validation_klass ||= 'Admin::GroupValidation'.constantize
      end

      def delegator_klass
        @delegator_klass ||= 'Admin::GroupDelegator'.constantize
      end

      def before_validate_params
        assignment = cname_params[:automatic_agent_assignment]
        return if assignment.blank? || !assignment.is_a?(Hash)

        assignment_type = fetch_assignment_type(assignment)
        freshdesk_settings = fetch_freshdesk_settings(assignment)
        populate_round_robin_params(freshdesk_settings) if freshdesk_settings && round_robin_assignment?(assignment_type)
        cname_params[:assignment_type] = assignment_type
      end

      # Helper methods

      def fetch_assignment_type(assignment)
        settings = assignment.try(:[], :settings)
        if settings.present?
          return unless settings.is_a?(Array)

          freshdesk_settings = fetch_freshdesk_settings(assignment)
          freshdesk_settings.nil? ? NO_ASSIGNMENT : ROUND_ROBIN_ASSIGNMENT
        else
          assignment.try(:[], :enabled) && assignment.try(:[], :type) == OMNI_CHANNEL ? OMNI_CHANNEL_ROUTING_ASSIGNMENT : NO_ASSIGNMENT
        end
      end

      def fetch_freshdesk_settings(assignment)
        return unless assignment[:settings].is_a?(Array)

        @fetch_freshdesk_settings ||= assignment[:settings].find { |s| s[:channel] == CHANNEL_NAMES[:freshdesk] }
      end

      def populate_round_robin_params(freshdesk_settings)
        populate_capping_limit(freshdesk_settings)
        populate_round_robin_type(freshdesk_settings)
      end

      def populate_capping_limit(freshdesk_settings)
        if (assignment_type_settings = freshdesk_settings[:assignment_type_settings])
          cname_params[:capping_limit] = assignment_type_settings[:capping_limit] if assignment_type_settings[:capping_limit].present?
        end
      end

      def populate_round_robin_type(freshdesk_settings)
        # lbrr / sbrr / lbrr_by_omniroute
        cname_params[:round_robin_type] = ASSIGNMENT_TYPE_MAPPINGS.invert[freshdesk_settings[:assignment_type]]
      end

      def round_robin_assignment?(assignment_type)
        assignment_type == ROUND_ROBIN_ASSIGNMENT
      end

      def freshdesk_assignment?(assignment_type)
        [NO_ASSIGNMENT, OMNI_CHANNEL_ROUTING_ASSIGNMENT].exclude?(assignment_type)
      end

      def render_201_with_location
        render "#{controller_path}/#{action_name}", status: :created
      end

      def build_attributes
        agent_ids = cname_params[:agent_ids]
        @item.build_agent_groups_attributes(agent_ids.join(',')) if agent_ids.present?
        @item.automatic_agent_assignment_settings = cname_params[:automatic_agent_assignment] if cname_params[:automatic_agent_assignment].present?
      end

      def set_custom_errors(item = @item)
        item = assignment_type_error_message(item) if item.errors[:round_robin_type].present?
        @error_options_mappings = item.errors[:assignment_type].present? ? ERROR_KEY_MAPPINGS.except(:round_robin_type) : ERROR_KEY_MAPPINGS
        ErrorHelper.rename_error_fields(@error_options_mappings, item)
      end

      # overriding error message from base validations
      def assignment_type_error_message(item)
        return item if item.error_options[:round_robin_type].present? && item.error_options[:round_robin_type][:code] == :require_feature
        item.errors[:round_robin_type] = :not_included
        item.error_options[:round_robin_type] = { list: ASSIGNMENT_TYPE_MAPPINGS.values.join(', '), code: :not_included }
        item
      end

      def error_options_mappings
        @error_options_mappings ||= ERROR_KEY_MAPPINGS
      end
  end
end
