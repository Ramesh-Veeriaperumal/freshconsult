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

end
