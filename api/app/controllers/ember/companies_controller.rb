module Ember
  class CompaniesController < ApiCompaniesController
    include HelperConcern
    include CustomerActivityConcern
    include BulkActionConcern
    include ContactsCompaniesConcern

    around_filter :run_on_slave, only: [:activities]

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

      def decorator_options_hash
        super.merge(sla: @sla_policies || {})
      end
  end
end
