module CommunityHelper

  def preview_portal(relative_path, category = nil)
    return if category.present? && category.portal_ids.empty?
    %(<span class="tooltip pull-right portal-preview-icon" title="#{t('solution.view_on_portal')}">
      #{link_to('<i class="ficon-open-in-portal fsize-21"></i>'.html_safe, portal_preview_path(relative_path, category), :target => "view-portal")}
    </span>).html_safe
  end

  def portal_preview_path relative_path, category, draft_preview = false
    path = relative_path
    unless (category.nil? || category.portal_ids.empty? || category.portal_ids.include?(current_portal.id))
      category_portal = category.portals.last
      path = ["#{category_portal.url_protocol}://", category_portal.host, relative_path, "#{'?different_portal=true' if draft_preview}"].join
    end
    path
  end

  def article_attachment_link(att, type)
    if @article.present? && att.parent_type == @article.class.name
      return %(#{solution_draft_attachments_delete_path(@article.parent_id, @article.language_id, type, att)}).html_safe
    end
  end

  def active_attachments(att_type, article)
    draft = article.draft
    return article.send(att_type) unless draft.present?

    (article.send(att_type).reject do |a|
      (draft.deleted_attachments(att_type) || []).include?(a.id)
    end) + draft.send(att_type)
  end

end
