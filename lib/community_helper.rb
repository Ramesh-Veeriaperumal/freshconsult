module CommunityHelper

  def preview_portal(relative_path, category = nil, extraClass = nil)
    category.portals.collect(&:id) if category.present?
    # Above line added just to preload the portals. The above line is otherwise useless
    return if category.present? && category.portal_ids.empty?
    %(<span class="tooltip pull-right portal-preview-icon #{extraClass}" data-placement="left" title="#{t('solution.view_on_portal')}">
      #{link_to('<i class="ficon-open-in-portal fsize-21"></i>'.html_safe, portal_article_path(relative_path, category), target: 'view-portal')}
    </span>).html_safe
  end

  def category_path_generator category
    path = nil
    unless (category.nil? || category.portal_ids.empty? || category.portal_ids.include?(current_portal.id))
      category_portal = category.portals.last
      path = ["#{category_portal.url_protocol}://", category_portal.host].join
    end
    path
  end

  def portal_article_path(relative_path, category, draft_preview = false)
    category_path = category_path_generator category
    relative_path = [category_path, relative_path, "#{'?different_portal=true' if draft_preview}"].join if category_path
    relative_path
  end

  def article_attachment_link(att, type)
    if @article.present? && att.parent_type == @article.class.name
      return %(#{solution_draft_attachments_delete_path(@article.parent_id, @article.language_id, type, att)}).html_safe
    end
  end

  def active_attachments(att_type, article)
    draft = article.draft
    return article.safe_send(att_type) unless draft.present?

    (article.safe_send(att_type).reject do |a|
      (draft.deleted_attachments(att_type) || []).include?(a.id)
    end) + (draft.safe_send(att_type).reject do |a|
      (draft.deleted_attachments(att_type) || []).include?(a.id)
    end)
  end

  def inline_manual_classes_for_multilingual
    classes = []
    classes << "eligible" if Account.current.features?(:multi_language)
    if Account.current.multilingual_available?
      classes << "available"
      classes << (Account.current.multilingual? ? "ml-enabled" : "ml-disabled")
    end
    classes.join(" ").html_safe
  end

end
