module DraftsConcern
  ATTACHMENT_TYPES = ['attachment', 'cloud_file'].freeze

  def pseudo_delete_article_attachment
    deleted = { @assoc.pluralize.to_sym => [@attachment.id] }
    @draft.meta[:deleted_attachments] ||= {}
    @draft.meta[:deleted_attachments].merge!(deleted) { |key, oldval, newval| oldval | newval }
    @draft.save
  end

  def load_attachment
    @assoc = (ATTACHMENT_TYPES.include?(params[:attachment_type]) && params[:attachment_type]) || ATTACHMENT_TYPES.first
    @attachment = @article.safe_send(@assoc.pluralize.to_sym).find_by_id(params[:attachment_id])
    @attachment = @article.draft.safe_send(@assoc.pluralize.to_sym).find_by_id(params[:attachment_id]) if @attachment.nil?
    log_and_render_404 if private_api? && !@attachment
  end

  private

    def private_api?
      params[:version] == 'private'
    end
end
