class Admin::SectionsController < ApiApplicationController
  include Admin::TicketFieldHelper
  include SectionBuilder

  before_filter :load_ticket_field, only: :index
  before_filter :validate_section
  before_filter :build_section, only: [:create, :update]

  decorate_views(decorate_object: [:create, :update, :show])

  def create
    @ticket_field.field_options[:section_present] = true unless @ticket_field.has_sections?
    @ticket_field.save!
    render_201_with_location
  end

  def update
    @ticket_field.save!
  end

  def destroy
    @item.destroy
    clear_on_empty_section # delete section_present if ticket_field section is empty
    @ticket_field.save!
    head 204
  end

  private

    def load_ticket_field
      @ticket_field = current_account.ticket_fields_only.find_by_id(params[:ticket_field_id])
      log_and_render_404 if @ticket_field.blank?
    end

    def scoper
      load_ticket_field
      return if @ticket_field.blank?

      (index? || show?) ? @ticket_field.field_sections : @ticket_field.sections
    end

    def build_object
      @item = scoper.build unless scoper.nil?
    end

    def launch_party_name
      FeatureConstants::TICKET_FIELD_REVAMP
    end

    def validate_filter_params
      params.permit(:ticket_field_id, *ApiConstants::DEFAULT_INDEX_FIELDS)
    end

    def validate_params
      cname_params.permit(*SECTION_PARAMS)
    end

    def validate_section
      options = {
        tf: @ticket_field
      }
      run_validation(options)
    end

    def validation_class
      'Admin::SectionsValidation'.constantize
    end

    def delegation_class
      'Admin::SectionsDelegator'.constantize
    end

    def load_object(items = scoper)
      return if @ticket_field.blank?

      @item = items.find { |section| section.id == params[:id].to_i }
      log_and_render_404 if @item.blank?
    end

    def load_objects(items = scoper)
      return if @ticket_field.blank?

      @items = items
      @decorated_items = construct_sections(@ticket_field)
    end

    def render_201_with_location
      render "#{controller_path}/#{action_name}", status: 201
    end
end
