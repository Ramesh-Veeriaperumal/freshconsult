class ApiRolesController < ApiApplicationController
  include HelperConcern
  include BulkActionConcern

  decorate_views

  before_filter :validate_bulk_update_params, only: [:bulk_update]

  def index
    super
    response.api_meta = { count: @items_count }
  end

  def bulk_update
    fetch_objects
    validate_and_bulk_update
    render_bulk_action_response(bulk_action_succeeded_items, bulk_action_errors)
  end

  private

    def preload_options
      { users: [ :user_companies, :roles, :default_user_company, :flexifield ] }
    end

    def fetch_objects(items = scoper)
      @items = items.preload(preload_options).where(id: params[cname][:ids]).to_a
    end

    def scoper
      current_action?(RoleConstants::BULK_UPDATE_METHOD) ? current_account.roles : current_account.roles_from_cache
    end

    def load_object
      @item = scoper.detect { |role| role.id == params[:id].to_i }
      log_and_render_404 unless @item
    end

    def constants_class
      :RoleConstants.to_s.freeze
    end

    def validate_bulk_update_params
      @validation_klass = RoleConstants::BULK_VALIDATION_CLASS
      validate_body_params
    end

    def validate_and_bulk_update
      @items_failed = @items.each_with_object([]) do |item, failed_list| 
        update_role(item)
        role_delegator = RoleDelegator.new(item, params[cname][:options])
        if role_delegator.valid?
          failed_list << item unless item.save!
        else
          (@validation_errors ||= {})[item.id] = role_delegator
          failed_list << item
        end
      end
    end

    def update_role(item)
      RoleConstants::ALLOWED_BULK_UPDATE_OPTIONS.each do |property|
        update_option = params[cname][:options][property]
        safe_send("update_#{property}", item, update_option) if update_option.present?
      end
    end

    def update_privileges(item, privileges)
      item.privilege_list = (item.abilities + privileges[:add].to_a - privileges[:remove].to_a).flatten.uniq
    end
end