class ArchiveDelegator < BaseDelegator
  validate :validate_display_ids, if: -> { @display_ids.present? }

  def initialize(record, options)
    @display_ids = options[:ids]
    @permissible_ticket_ids = options[:permissible_ids]
    super(record, options)
  end

  def validate_display_ids
    valid_ids = Account.current.tickets.visible.where(display_id: @permissible_ticket_ids, status: ApiTicketConstants::CLOSED).pluck(:display_id)
    invalid_ids = @display_ids - valid_ids
    if invalid_ids.present?
      errors[:ids] << :invalid_id_list
      (self.error_options ||= {}).merge!({ ids: { invalid_ids: "#{invalid_ids.join(', ')}" } })
    end
  end
end
