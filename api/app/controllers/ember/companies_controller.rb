module Ember
  class CompaniesController < ApiCompaniesController
    include HelperConcern
    include CustomerActivityConcern
    include BulkActionConcern
    include ContactsCompaniesConcern
    include SegmentConcern

    SLAVE_ACTIONS = %w(index activities).freeze
    before_filter :validate_and_process_query_hash, only: [:index], if: :segments_enabled?

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
      @item.assign_attributes(validatable_delegator_attributes)
      return unless validate_delegator(@item, delegator_params)
      mark_avatar_for_destroy
      Company.transaction do
        @item.avatar.save if params[cname].key?('avatar_id') && @item.avatar    # for deletion if marked_for_deletion
        assign_avatar
        params[cname].except(:avatar_id).present? ? @item.update_attributes!(params[cname].except(:avatar_id)) : @item.save!
      end
      @item.reload
      render :show
    rescue
      render_custom_errors
    end

    def index
      if filter_api?
        handle_segments
      elsif params[:ids].present?
        @items = scoper.where(id: params[:ids]).preload(preload_options)
      else
        super
        @sideload_options = @validator.include_array || []
        response.api_meta = { count: @items_count }
      end
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

      def validatable_delegator_attributes
        params[cname].select do |key, value|
          if CompanyConstants::VALIDATABLE_DELEGATOR_ATTRIBUTES_HASH[key] == true
            params[cname].delete(key)
            true
          end
        end
      end

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
          avatar_id: params[cname][:avatar_id],
          default_fields: params[cname].except(:custom_field)
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
        all_active_sla_policies = current_account.sla_policies.active
        company_sla_policies = []
        default_sla_policy = []
        all_active_sla_policies.each do |policy|
          if !policy.is_default && policy.conditions[:company_id].present? && policy.conditions[:company_id].include?(@item.id)
            company_sla_policies.push(policy)
          elsif policy.is_default
            default_sla_policy.push(policy)
          end
        end
        @sla_policies = company_sla_policies.empty? ? default_sla_policy : company_sla_policies
      end

      def decorator_options_hash
        super.merge(sla: @sla_policies || {})
      end

      def company_filters
        current_account.company_filters
      end

      def current_segment
        @current_segment ||= company_filters.find_by_id(params[:filter])
      end
  end
end
