class BulkLinkTrackerDelegator < BaseDelegator
  validate :tracker_ticket, on: :bulk_link

  def initialize(record, options = {})
    super(record, options)
  end

  def tracker_ticket
    errors[:id] << :unable_to_perform unless self && tracker_ticket? && !spam_or_deleted?
  end
end
