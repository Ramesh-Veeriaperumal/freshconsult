class PortalDecorator < ApiDecorator
  delegate :id, :name, :host, :product_id, :main_portal?, :ssl_enabled?, :language,
    :created_at, :updated_at, to: :record

  def to_hash
    {
      id: id,
      name: name,
      host: host,
      default: main_portal?,
      product_id: product_id,
      ssl_enabled: ssl_enabled?,
      solution_category_ids: record.portal_solution_categories.pluck(:solution_category_meta_id),
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }.merge(forums_enabled? ? { discussion_category_ids: record.portal_forum_categories.pluck(:forum_category_id) } : {})
  end

  private

    def forums_enabled?
      Account.current.features?(:forums) &&
        !Account.current.features?(:hide_portal_forums)
    end
end
