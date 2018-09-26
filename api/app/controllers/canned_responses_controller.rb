class CannedResponsesController < ApiApplicationController
  include HelperConcern
  include TicketConcern
  include HelpdeskAccessMethods

  decorate_views(decorate_objects: [:folder_responses])

  before_filter :canned_response_permission?, :load_ticket, only: [:show]
  before_filter :filter_ids, only: :index
  before_filter :load_folder, :validate_filter_params, only: :folder_responses
  SLAVE_ACTIONS = %w[index search].freeze

  MAX_IDS_COUNT = 10

  def folder_responses
    @items = accessible_from_esv2('Admin::CannedResponses::Response', { size: 300 }, default_visiblity, 'raw_title', @folder.id)
    @items = fetch_ca_responses_from_db(@folder.id) if @items.nil?
    # pagination is handled here because load_objects is overridden here for the index action
    @items_count = @items.count
    @items = paginate_items(@items)
    response.api_meta = { count: @items_count }
  end

  private

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

    def canned_response_permission?
      render_request_error(:access_denied, 403) unless @item.visible_to_me?
    end

    def fetch_ca_responses_from_db(folder_id = nil)
      options = [{ folder_id: @folder.id }]
      ca_responses = accessible_elements(current_account.canned_responses,
                                         query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', *options))
      (ca_responses || []).compact
    end
end
