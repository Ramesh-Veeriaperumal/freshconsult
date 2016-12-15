class TicketFilterDelegator < BaseDelegator

  attr_accessor :ticket_filter, :filter

  validate :validate_filter, if: -> { filter.present? }

  def initialize(record, options = {})
    super(record, options)
    @filter = options[:filter]
  end

  def validate_filter
    if filter.to_i.to_s == filter
      @ticket_filter = Account.current.ticket_filters.find_by_id(filter)
      errors[:filter] << :"is invalid" if @ticket_filter.nil? || !@ticket_filter.has_permission?(User.current)
    else
      @ticket_filter = Account.current.ticket_filters.new(Helpdesk::Filters::CustomTicketFilter::MODEL_NAME).default_filter(filter)
    end
  end
end
