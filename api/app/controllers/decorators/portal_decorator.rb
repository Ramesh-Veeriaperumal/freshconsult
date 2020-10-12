class PortalDecorator < ApiDecorator
  delegate :id, :name, :host, :product_id, :main_portal?, :ssl_enabled?, :language,
           :created_at, :updated_at, :preferences, :helpdesk_logo, :portal_name, to: :record

  def to_hash
    portal_hash = {
      id: id,
      name: portal_name,
      host: host,
      default: main_portal?,
      product_id: product_id,
      ssl_enabled: ssl_enabled?,
      solution_category_ids: record.portal_solution_categories.pluck(:solution_category_meta_id),
      preferences: record.preferences,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      helpdesk_logo: logo,
      language: record.language
    }
    portal_hash[:discussion_category_ids] = record.portal_forum_categories.pluck(:forum_category_id) if forums_enabled?
    portal_hash[:fav_icon_url] = record.fetch_fav_icon_url if record.fav_icon
    portal_hash
  end

  private

    def logo
      helpdesk_logo.blank? ? nil : AttachmentDecorator.new(helpdesk_logo, 7.days, false).to_hash
    end

    def forums_enabled?
      Account.current.features?(:forums) &&
        !Account.current.hide_portal_forums_enabled?
    end
end
