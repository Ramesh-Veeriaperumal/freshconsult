class Archive::TicketsController < ::ApiApplicationController
  include Support::TicketsHelper
  include HelperConcern

  decorate_views(decorate_objects: [:index])
  PRELOAD_OPTIONS = [:company, { requester: [:avatar] }].freeze

  before_filter :verify_ticket_permission, only: [:show, :destroy]

  def show
    sideload_associations if @include_validation.include_array.present?
    super
  end

  def destroy
    begin
      note_ids = notes_available_in_s3? ? @item.archive_notes.pluck(:id) : []
      Archive::DeleteArchiveTicket.perform_async({:ticket_id => @item.id, :note_ids => note_ids })
      @item.destroy
      head 204
    rescue => e
      NewRelic::Agent.notice_error(e, description: 'Error occured in deletion of archive ticket #{@item.id} for Account #{current_account.id}')
      render_base_error(:internal_error, 500)
    end
  end

  private

    def feature_name
      :archive_tickets
    end

    def scoper
      current_account.archive_tickets
    end

    def load_object(items = scoper)
      @item = items.find_by_display_id(params[:id])
      log_and_render_404 unless @item
    end

    def sideload_associations
      @include_validation.include_array.each { |association| increment_api_credit_by(1) }
    end

    def decorator_options(options = {})
      options[:sideload_options] = sideload_options.to_a if show?
      options[:name_mapping] = @name_mapping || get_name_mapping
      super(options)
    end

    def get_name_mapping
      # will be called only for index and show.
      # We want to avoid memcache call to get custom_field keys and hence following below approach.
      mapping = Account.current.ticket_field_def.ff_alias_column_mapping
      mapping.each_with_object({}) { |(ff_alias, column), hash| hash[ff_alias] = Archive::TicketDecorator.display_name(ff_alias) } if @item || @items.present?
    end

    def sideload_options
      @include_validation.try(:include_array)
    end

    def validate_url_params
      params.permit(*ApiTicketConstants::SHOW_FIELDS, *ApiConstants::DEFAULT_PARAMS)
      @include_validation = TicketIncludeValidation.new(params)
      render_errors @include_validation.errors, @include_validation.error_options unless @include_validation.valid?
    end

    def notes_available_in_s3?
      current_shard = ActiveRecord::Base.current_shard_selection.shard.to_s
      ArchiveNoteConfig[current_shard] && (@item.id <= ArchiveNoteConfig[current_shard].to_i)
    end

    def verify_ticket_permission(user = api_current_user, ticket = @item)
      unless user.has_ticket_permission?(ticket) && destroy_privilege?(user)
        Rails.logger.error "Params: #{params.inspect} User: #{user.id}, #{user.email} doesn't have permission to ticket display_id: #{ticket.display_id}"
        render_request_error :access_denied, 403
        return false
      end
      true
    end

    def destroy_privilege?(user)
      return true unless params["action"] === "destroy"
      user.privilege?(:delete_ticket)
    end
    
end
