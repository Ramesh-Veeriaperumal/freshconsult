class Archive::TicketsController < ::ApiApplicationController
  include Support::TicketsHelper
  include HelperConcern

  decorate_views(decorate_objects: [:index])
  PRELOAD_OPTIONS = [:company, { requester: [:avatar] }].freeze

  def show
    sideload_associations if @include_validation.include_array.present?
    super
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
end
