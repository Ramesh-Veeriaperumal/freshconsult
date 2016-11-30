module Ember
  class CompaniesController < ApiCompaniesController
    include HelperConcern

    def index
      super
      load_sla_policies if sideload_options.include?('sla_policies')
      response.api_meta = { count: @items_count }
    end

    def activities
      return unless validate_filter_params
      @company_activities = (params[:type] == 'archived_tickets' ? archived_ticket_activities : ticket_activities).take(CompanyConstants::MAX_ACTIVITIES_COUNT)
      response.api_root_key = :activities
      response.api_meta = { "more_#{params[:type]}" => true } if @total_tickets.length > CompanyConstants::MAX_ACTIVITIES_COUNT
    end

    private

      def validate_filter_params
        @validation_klass = 'CompanyFilterValidation'
        validate_url_params
      end

      def sideload_options
        @sideload_options ||= @validator.include_array || []
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

      def load_sla_policies
        @company_sla_hash = {}
        @items.each do |item|
          @company_sla_hash[item.id] = sla_policies(item)
        end
      end

      def sla_policies(company)
        @sla_policies ||= current_account.sla_policies.rule_based.active
        sla = @sla_policies.select do |policy|
          policy.conditions[:company_id].present? && policy.conditions[:company_id].include?(company.id)
        end
        return @default_policy ||= current_account.sla_policies.default if sla.empty?
        sla
      end

      def ticket_activities
        @total_tickets = current_account.tickets.permissible(api_current_user).all_company_tickets(@item.id).visible.newest(CompanyConstants::MAX_ACTIVITIES_COUNT + 1).order('created_at DESC')
      end

      def archived_ticket_activities
        return [] unless current_account.features_included?(:archive_tickets)
        @total_tickets = current_account.archive_tickets.permissible(api_current_user).all_company_tickets(@item.id).newest(CompanyConstants::MAX_ACTIVITIES_COUNT + 1).order('created_at DESC')
      end

      def decorator_options_hash
        super.merge(sla: @company_sla_hash || {})
      end
  end
end
