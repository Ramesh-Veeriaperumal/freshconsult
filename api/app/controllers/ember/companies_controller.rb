module Ember
  class CompaniesController < ApiCompaniesController
    include HelperConcern
    include BulkActionConcern
    include ContactsCompaniesConcern

    def create
      delegator_params = construct_delegator_params
      return unless validate_delegator(@item, delegator_params)
      assign_avatar
      if @item.save
        render :show, status: 201
      else
        render_custom_errors
      end
    end

    def update
      delegator_params = construct_delegator_params
      custom_fields = params[cname].delete(:custom_field)
      @item.assign_attributes(custom_field: custom_fields)
      return unless validate_delegator(@item, delegator_params)
      mark_avatar_for_destroy
      Company.transaction do
        @item.update_attributes!(params[cname].except(:avatar_id))
        assign_avatar
      end
      @item.reload
      render :show
    rescue
      render_custom_errors
    end

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

    def bulk_delete
      bulk_action do
        @items_failed = []
        @items.each do |item|
          @items_failed << item unless item.destroy
        end
      end
    end

    private

      def fetch_objects(items = scoper)
        @items = items.find_all_by_id(params[cname][:ids])
      end

      def validate_filter_params
        @validation_klass = 'CompanyFilterValidation'
        validate_query_params
      end

      def construct_delegator_params
        {
          custom_fields: params[cname][:custom_field],
          avatar_id: params[cname][:avatar_id]
        }
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
