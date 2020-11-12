class CannedResponsesController < ApiApplicationController
  include HelperConcern
  include TicketConcern
  include CannedResponseConcern
  include AttachmentConcern
  include HelpdeskAccessMethods
  include BulkApiJobsHelper

  decorate_views(decorate_objects: [:folder_responses])

  before_filter :canned_response_permission?, :load_ticket, only: [:show, :update]
  before_filter :filter_ids, only: :index
  before_filter :load_folder, :validate_filter_params, only: :folder_responses
  before_filter :check_bulk_params_limit, :validate_ca_response_params, only: :create_multiple
  SLAVE_ACTIONS = %w[index search].freeze

  MAX_IDS_COUNT = 10

  def create_multiple
    @errors = []
    @job_id = request.uuid
    initiate_bulk_job(CannedResponseConstants::BULK_API_JOBS_CLASS, params[cname][:canned_responses], @job_id, action_name)
    @job_link = current_account.bulk_job_url(@job_id)
    render('bulk_api_jobs/response', status: 202) if @errors.blank?
  end

  def folder_responses
    @items = fetch_ca_responses_from_db(@folder.id)
    # pagination is handled here because load_objects is overridden here for the index action
    @items_count = @items.count
    @items = paginate_items(@items)
    response.api_meta = { count: @items_count }
  end

  def self.wrap_params
    CannedResponseConstants::WRAP_PARAMS
  end

  private

    def assign_protected
      @item.account = current_account
      build_attachments
      @item.shared_attachments = @item.shared_attachments
    end

    def valid_content_type?
      return true if super
      allowed_content_types = CannedResponseConstants::ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym] || [:json]
      allowed_content_types.include?(request.content_mime_type.ref)
    end

    def sanitize_params
      @delegator_klass = 'CannedResponseDelegator'
      validate_delegator(@item, cname_params.slice(*CannedResponseConstants::DELEGATE_FIELDS))
      construct_canned_response
    end

    def validate_params
      @validation_klass = 'CannedResponsesValidation'
      params[cname].permit(*CannedResponseConstants::CREATE_FIELDS)
      canned_response = validation_klass.new(params[cname], @item, string_request_params?)
      render_custom_errors(canned_response, true) unless canned_response.valid?(action_name.to_sym)
    end

    def validate_filter_params
      params.permit(*ApiConstants::DEFAULT_INDEX_FIELDS, :ids)
    end

    def validate_url_params
      @validation_klass = 'CannedResponseFilterValidation'
      validate_query_params
    end

    def sideload_options
      @validator.include_array
    end

    def decorator_options
      options = {}
      if show?
        options[:sideload_options] = (sideload_options || [])
        options[:ticket] = @ticket
      end
      super(options)
    end

    def constants_class
      :CannedResponseConstants.to_s.freeze
    end

    def load_objects
      @items = scoper.where(id: @ids)
      @items.select!(&:visible_to_me?)

      # Instead of using validation to give 4xx response for bad ids,
      # we are going to tolerate and send response for the good ones alone.
      # Because the primary use case for this is Recently used Canned Responses
      log_and_render_404 if @items.blank?
    end

    def load_folder
      @folder = current_account.canned_response_folders.find_by_id(params[:id])
      log_and_render_404 unless @folder
    end

    def filter_ids
      @ids = params[:ids].to_s.split(',').map(&:to_i).reject(&:zero?).first(MAX_IDS_COUNT)
      log_and_render_404 if @ids.blank?
    end

    def scoper
      current_account.canned_responses.preload(helpdesk_accessible: [:group_accesses, :user_accesses])
    end

    def load_ticket
      return true unless params[:ticket_id]
      @ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
      if @ticket
        return verify_ticket_state_and_permission(api_current_user, @ticket)
      else
        log_and_render_404
        false
      end
    end

    def check_bulk_params_limit
      max_limit = CannedResponseConstants::BULK_API_PARAMS_LIMIT
      if params[cname][:canned_responses].size > max_limit
        render_request_error(:bulk_api_limit_exceed, 400,
                             resource: 'canned_responses', current: params[cname][:canned_responses].size, max: max_limit)
      end
    end

    def validate_ca_response_params
      params[cname][:canned_responses].each do |canned_response|
        ca_response = CannedResponsesValidation.new(canned_response, nil, string_request_params?)
        render_custom_errors(ca_response, true) && break unless ca_response.valid?(action_name)
      end
    end

    def canned_response_permission?
      render_request_error(:access_denied, 403) unless @item.visible_to_me?
    end

    def fetch_ca_responses_from_db(folder_id = nil)
      options = [{ folder_id: @folder.id }]
      ca_responses = accessible_elements(current_account.canned_responses,
                                         query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', *options))
      (ca_responses || []).compact
    end

    def build_attachments
      build_shared_attachment
      build_shared_attachment_with_ids
    end

    wrap_parameters(*wrap_params)
end
