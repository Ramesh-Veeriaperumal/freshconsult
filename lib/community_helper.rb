module CommunityHelper

  def preview_portal(relative_path, category = nil)
    path = relative_path
    unless (category.nil? || category.portal_ids.empty? || category.portal_ids.include?(current_portal.id))
      path = ["#{category.portals.last.url_protocol}://", category.portals.last.host, relative_path].join
    end

    %(<span class="tooltip pull-right portal-preview-icon" title="#{t('solution.view_on_portal')}">
      #{link_to('<i class="ficon-open-in-new-window fsize-21"></i>'.html_safe, path, :target => "_blank")}
    </span>).html_safe
  end

  def article_attachment_link_helper(att, type)
  	type = @article.class.reflections[(type.to_s.pluralize).to_sym].options[:as]
  	if @article.present? && att.send("#{type}_type") == @article.class.name
  		return %(#{solution_article_attachments_delete_path(@article, type, att)}).html_safe
  	end
  	return nil
  end

  def active_attachments(att_type, draft, article)
  	return article.send(att_type) unless article.draft.present?
  	att = article.send(att_type) + draft.send(att_type)
  	deleted_att_ids = []
  	if draft.meta.present? && draft.meta[:deleted_attachments].present? && draft.meta[:deleted_attachments][att_type].present?
  		deleted_att_ids = draft.meta[:deleted_attachments][att_type]
  	end
  	return att.select {|a| !deleted_att_ids.include?(a.id)}
  end

end
