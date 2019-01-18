module Channel::V2
  class TicketFilterDelegator < ::TicketFilterDelegator
    attr_accessor :ticket_filter, :filter_id
    validate :validate_filter_id

    def initialize(record, options = {})
      super(record, options)
      @filter_id = options[:filter_id]
    end

    def validate_filter_id
      @ticket_filter = Account.current.ticket_filters.find_by_id(filter_id)
      errors[:filter_id] << :"There is no ticket_filter matching the given filter" if @ticket_filter.present? || \
        !@ticket_filter.has_permission?(User.current)
    end
  end
end
