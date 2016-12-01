module Ember
  class CompaniesController < ApiCompaniesController
    include HelperConcern

    def index
      super
      @sideload_options = @validator.include_array || []
      response.api_meta = { count: @items_count }
    end

    def activities
      return unless validate_filter_params
      @company_activities = (params[:type] == 'archived_tickets' ? archived_ticket_activities : ticket_activities).take(CompanyConstants::MAX_ACTIVITIES_COUNT)
      response.api_root_key = :activities
      response.api_meta = { "more_#{params[:type]}" => true } if @total_tickets.length > CompanyConstants::MAX_ACTIVITIES_COUNT
    end

    def show
      super
      load_sla_policy
    end

    private

      def validate_filter_params
        @validation_klass = 'CompanyFilterValidation'
        validate_query_params
      end

      def load_objects
        super (params[:letter] ? scoper.where(*filter_conditions) : nil)
      end

      def filter_conditions
        ['name like ?', "#{params[:letter]}%"]
      end

      def constants_class
        :CompanyConstants.to_s.freeze
      end

      def load_sla_policy
        active_sla_policies = current_account.sla_policies.rule_based.active
        sla = active_sla_policies.select do |policy|
          policy.conditions[:company_id].present? && policy.conditions[:company_id].include?(@item.id)
        end
        @sla_policies = sla.empty? ? current_account.sla_policies.default : sla
      end

      def ticket_activities
        @total_tickets = current_account.tickets.permissible(api_current_user).all_company_tickets(@item.id).visible.newest(CompanyConstants::MAX_ACTIVITIES_COUNT + 1).order('created_at DESC')
      end

      def archived_ticket_activities
        return [] unless current_account.features_included?(:archive_tickets)
        @total_tickets = current_account.archive_tickets.permissible(api_current_user).all_company_tickets(@item.id).newest(CompanyConstants::MAX_ACTIVITIES_COUNT + 1).order('created_at DESC')
      end

      def decorator_options_hash
        super.merge(sla: @sla_policies || {})
      end
  end
end
