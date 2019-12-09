class Admin::TicketFieldsController < ApiApplicationController
  include Admin::TicketFieldHelper
  include Admin::TicketFieldConstants
  include TicketFieldBuilder

  attr_accessor :section_mappings, :tf_params

  before_filter :validate_ticket_field
  before_filter :update_ticket_field_attributes, only: [:create, :update]

  decorate_views(decorate_objects: [:index])

  def create
    # Rails.logger.info "\n\n CNAME PARAMS #{params.inspect}\n\n"
    # Rails.logger.info "\n\n CREATE \n #{@item.inspect}, \n\n #{@item.child_levels.inspect}\n\n #{@item.nested_ticket_fields.inspect}\n\n"
    if move_to_background_job?
      create_without_relationship
      Admin::TicketFieldWorker.perform_async(account_id: Account.current.id, ticket_field: @item)
    elsif !@item.save!
      render_custom_errors
    else
      @decorated_item = @item && Admin::TicketFieldDecorator.new(@item, include: params[:include])
      render_201_with_location
    end
  end

  def update
    # Rails.logger.info "\n\n UPDATE PARAMS #{params.inspect}\n\n"
    # Rails.logger.info "\n\n UPDATE \n #{@item.inspect}, \n\n #{@item.child_levels.inspect}\n\n #{@item.nested_ticket_fields.inspect}\n\n"
    if move_to_background_job?
      update_without_relationship
      Admin::TicketFieldWorker.perform_async(account_id: Account.current.id, ticket_field: @item)
    else
      ActiveRecord::Base.transaction do
        save_picklist_choices
        unless @item.save!
          render_custom_errors
        end
      end
      @decorated_item = @item && Admin::TicketFieldDecorator.new(@item, include: params[:include])
    end
  end

  def destroy
    @item.destroy
    head 204
  end

  private

    def before_build_object
      @item = scoper.new
    end

    def validate_url_params
      params.permit(*SHOW_FIELDS)
    end

    def validate_filter_params
      params.permit(*INDEX_FIELDS)
    end

    def validate_ticket_field
      run_validation
    end

    def validate_params
      allowed_fields = "#{constants_class}::#{action_name.upcase}_FIELDS".constantize
      if params[cname].blank?
        custom_empty_param_error
      else
        params[cname].permit(*allowed_fields)
      end
    end

    def load_object
      @item = current_account.ticket_fields_with_nested_fields.find_by_id(params[:id])
      @decorated_item = @item && Admin::TicketFieldDecorator.new(@item, include: params[:include])
      log_and_render_404 if @item.blank? || @item.parent_id.present?
    end

    def load_objects(items = scoper)
      # This method has been overridden to avoid pagination.
      @items = items
      @decorated_items = items.map { |item| Admin::TicketFieldDecorator.new(item, include: params[:include]) }
    end

    def launch_party_name
      FeatureConstants::TICKET_FIELD_REVAMP
    end

    def delegation_class
      'Admin::TicketFieldsDelegator'.constantize
    end

    def validation_class
      'Admin::TicketFieldsValidation'.constantize
    end

    def constants_class
      'Admin::TicketFieldConstants'.freeze
    end

    def scoper
      if index_or_show?
        current_account.ticket_fields_from_cache.select(&:condition_based_field)
      else
        current_account.ticket_fields_with_nested_fields
      end
    end

    def index_or_show?
      index? || show?
    end
end
