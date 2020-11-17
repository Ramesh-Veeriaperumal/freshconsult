module Ember
  module Tickets
    class BulkActionsController < ::TicketsController
      include BulkActionConcern
      include TicketConcern
      include HelperConcern
      include AttachmentConcern
      include Helpdesk::ToggleEmailNotification
      include AssociateTicketsHelper

      before_filter :link_tickets_enabled?, only: [:bulk_link, :bulk_unlink]

      TICKET_ASSOCIATE_CONSTANTS_CLASS = :TicketAssociateConstants.to_s.freeze

      def bulk_link
        validate_bulk_associated_objects do
          @tracker = Account.current.tickets.find_by_display_id(params[:tracker_id])
          @delegator_klass = TicketAssociateConstants::TRACKER_DELEGATOR_CLASS
          return unless validate_delegator(@tracker)
          fetch_objects
        end
        ::Tickets::LinkTickets.perform_async(related_ticket_ids: @tickets.map(&:display_id), 
          tracker_id: params[:tracker_id]) if @tickets.present?
        @items ? render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors) : return
      end

      def bulk_unlink
        validate_bulk_associated_objects do
          fetch_objects(scoper, false)
        end
        ::Tickets::UnlinkTickets.perform_async(related_ticket_ids: @tickets.map(&:display_id)) if @tickets.present?
        @items ? render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors) : return
      end

      def bulk_execute_scenario
        return unless validate_body_params
        sanitize_body_params
        @delegator_klass = 'ScenarioDelegator'
        return unless validate_delegator(@item, scenario_id: cname_params[:scenario_id])
        fetch_objects
        validate_scenario_execution if actions_contain_close?(@delegator.va_rule)
        skip_fsm_tickets if Account.current.field_service_management_enabled?
        execute_scenario
        render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors)
      end

      def self.wrap_params
        ApiTicketConstants::BULK_WRAP_PARAMS
      end

      protected

        def requires_feature(feature)
          return if current_account.has_feature?(feature)

          render_request_error(:require_feature, 403, feature: feature.to_s.titleize)
        end

      private

        def feature_name
          :scenario_automation if action_name.to_sym == :bulk_execute_scenario
        end

        def validate_items_to_bulk_link_or_unlink
          @items_failed = []
          @validation_errors = {}
          @delegator_klass = TicketAssociateConstants::DELEGATOR_CLASS
          @dklass_computed = @delegator_klass.constantize
          @items.each do |item|
            @delegator = delegator_klass.new(item)
            unless @delegator.valid?(action_name.to_sym)
              @items_failed << item
              @validation_errors.merge!(item.display_id => @delegator)
            end
          end
        end

        def validate_bulk_associated_objects
          @constants_klass  = TICKET_ASSOCIATE_CONSTANTS_CLASS
          @validation_klass = TicketAssociateConstants::VALIDATION_CLASS
          return unless validate_body_params
          yield
          if @items.present?
            validate_items_to_bulk_link_or_unlink
            @tickets = @items - @items_failed
          end
        end

        def fields_to_validate
          super
        end

        def actions_contain_close?(va_rule)
          status_action = va_rule.action_data.find {|x| x.symbolize_keys!; x[:name] == 'status'} 
          status_action && close_action?(status_action[:value].to_i)
        end

        def close_action? status
          [CLOSED, RESOLVED].include? status.to_i
        end

        def skip_fsm_tickets
          @fsm_items = []
          @items.delete_if do |item|
            if item.service_task?
              @fsm_items << item
              true
            end
          end
        end

        def validate_scenario_execution
          @items_failed = []
          @validation_errors = {}
          fetch_ticket_fields_mapping
          va_rule = @delegator.va_rule
          @items.each do |item| 
            unless validate_rule_execution(va_rule, item)
              @items_failed << item
              @validation_errors.merge!(item.display_id => @delegator)
            end
          end
        end

        def validate_rule_execution(va_rule, item)
          va_rule.trigger_actions_for_validation(item, api_current_user)
          delegator_hash = { ticket_fields: @ticket_fields, statuses: @statuses, request_params: [:status] }
          @delegator = TicketBulkUpdateDelegator.new(item, delegator_hash)
          @delegator.valid?
        end

        def execute_scenario
          return unless bulk_action_succeeded_items.present?
          ::Tickets::BulkScenario.perform_async(ticket_ids: bulk_action_succeeded_items, scenario_id: cname_params[:scenario_id])
        end

        def fetch_objects(items = scoper, check_permission = true)
          ids = check_permission ? permissible_ticket_ids(cname_params[:ids]) : cname_params[:ids]
          @items = items.preload(preload_options).find_all_by_param(ids)
        end

        def preload_options
          [:schema_less_ticket, :flexifield, :ticket_states, :ticket_body]
        end

        def constants_class
          :ApiTicketConstants.to_s.freeze
        end
        wrap_parameters(*wrap_params)
    end
  end
end
