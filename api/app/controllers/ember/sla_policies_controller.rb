module Ember
  class SlaPoliciesController < ApiSlaPoliciesController
    decorate_views(decorate_object: [:show])
    before_filter :fetch_rule_position, only: [:update], if: :position_changed? # re-order

    private

      def scoper
        current_account.sla_policies_reorder
      end

      def after_load_object
        super unless ['show', 'update'].include?(action_name)
      end

      def constants_class
        'Ember::SlaPolicyConstants'.freeze
      end

      def allowed_param_fields
        fields = "#{constants_class}::#{action_name.upcase}_FIELDS".constantize
        fields = fields - "#{constants_class}::DEFAULT_POLICY_UNEDITABLE_FIELDS".constantize if @item.try(:is_default)
        fields
      end

      def render_201_with_location(template_name: "api_sla_policies/#{action_name}", location_url: 'sla_policies_url', item_id: @item.id)
        render template_name, location: safe_send(location_url, item_id), status: 201
      end

      def tranform_sla_target_keys(sla_target, priority, sla_detail)
        sla_detail = ActiveSupport::HashWithIndifferentAccess.new(priority: priority, name: SlaPolicyConstants::SLA_DETAILS_NAME[priority]) if action_name.eql?('create')
        sla_detail[:sla_target_time] = ActiveSupport::HashWithIndifferentAccess.new(
          first_response_time: sla_target[:first_response_time],
          every_response_time: sla_target[:every_response_time],
          resolution_due_time: sla_target[:resolution_due_time]
        )
        sla_detail[:response_time] = Helpdesk::SlaDetail.new.target_time_in_seconds(sla_target[:first_response_time])
        sla_detail[:next_response_time] = Helpdesk::SlaDetail.new.target_time_in_seconds(sla_target[:every_response_time]) if sla_target[:every_response_time].present?
        sla_detail[:resolution_time] = Helpdesk::SlaDetail.new.target_time_in_seconds(sla_target[:resolution_due_time])
        sla_detail[:override_bhrs] = !sla_target[:business_hours]
        sla_detail[:escalation_enabled] = sla_target[:escalation_enabled]
        if action_name.eql?('create')
          sla_detail[:skip_iso_format_conversion] = true
          @item.sla_details.build(sla_detail)
        else
          sla_detail.skip_iso_format_conversion = true
        end
      end

      def position_changed?
        params[cname].key?(:position)
      end

      def fetch_rule_position
        rules_position = current_account.sla_policies_reorder.pluck(:position)
        params[cname][:position] = rules_position[params[cname][:position] - 1]
      end
  end
end
