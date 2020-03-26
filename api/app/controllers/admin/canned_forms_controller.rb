class Admin::CannedFormsController < ApiApplicationController
  include HelperConcern

  decorate_views(decorate_objects: [:index], decorate_object: [:show, :update])

  def index
    super
    response.api_meta = { count: @items_count }
  end

  def update
    if @item.update_attributes(cname_params)
      render "#{controller_path}/show"
    else
      render_custom_errors
    end
  end

  def destroy
    @item.update_attributes(deleted: true)
    head 204
  end

  def create_handle
    cname_params.permit(*CannedFormConstants::CREATE_HANDLE_FIELDS)
    load_object
    ticket = Helpdesk::Ticket.find_by_param(cname_params[:ticket_id], current_account)
    return render_request_error(:absent_in_db, 400, resource: :record, attribute: :id) unless ticket
    @handle = @item.canned_form_handles.build(ticket_id: ticket.id)
    render_custom_errors(@handle) unless @handle.save
  end

  private

    def feature_name
      FeatureConstants::CANNED_FORMS
    end

    def scoper
      current_account.canned_forms.active_forms
    end

    def validate_params
      validate_body_params
    end

    def render_201_with_location(template_name: 'admin/canned_forms/show', location_url: 'canned_form_url', item_id: @item.id)
      render template_name, location: safe_send(location_url, item_id)
    end

    def render_errors(errors, meta = {})
      super
    rescue StandardError => e
      # Handle Formserv service errors
      # {:fields=>{:status=>400, :code=>1002, :message=>"Form version mismatch", :link=>"", :developerMessage=>"Form's version from request does not match with form's version in service"}}
      Rails.logger.error("Formserv :: Error :: #{e.message} :: #{e.backtrace}")
      @errors = []
      errors.to_h.each_value do |val|
        @errors << ErrorHelper.bad_request_error('Formserv', val[:message], meta)
      end
      log_error_response @errors
      render '/bad_request_error', status: ErrorHelper.find_http_error_code(@errors)
    end

    def constants_class
      'CannedFormConstants'.freeze
    end
end
