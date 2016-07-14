class Solutions::CategoryDecorator < ApiDecorator
  delegate :name, :description, :parent, to: :record

  def portal_ids_visible?
    @portal_ids_visible ||= Account.current.has_multiple_portals?
  end

  def visible_in
  	record.parent.portal_solution_categories.map(&:portal_id)
  end
end
