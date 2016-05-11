class Solutions::CategoryDecorator < ApiDecorator
  delegate :name, :description, to: :record

  def portal_ids_visible?
  	@portal_ids_visible ||= Account.current.portals.count > 1
  end

  def parent
  	record.parent
  end
end