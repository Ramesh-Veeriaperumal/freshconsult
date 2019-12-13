class DraftObserver < ActiveRecord::Observer
  include Solution::ArticleVersioning
  observe Solution::Draft

  def after_save(item)
    versioning_after_save(item) 
    clear_approvals_on_content_change(item) if !item.id_changed? && content_changed?(item)
  end

  def after_destroy(item)
    version_discard_or_destroy(item) if item.account.article_versioning_enabled?
    clear_approvals(item)
  end

  private

    def versioning_after_save(item)
      return if !item.account.article_versioning_enabled? || item.false_delete_attachment_trigger
      item.article.flush_hits! if item.unpublishing # Flush article and version votes on article unpublish
      item.cancelling ? version_discard_or_destroy(item) : version_create_or_update(item)
    end

    def clear_approvals_on_content_change(item)
      return unless Account.current.article_approval_workflow_enabled?

      helpdesk_approval = item.article.helpdesk_approval
      return unless helpdesk_approval

      # If article is in approved state we need to clear approval status.
      # if the article in review state, we don't need to clear the approval status if the user is one of the approver of the article.
      if helpdesk_approval.approved? || (helpdesk_approval.in_review? && (!User.current.privilege?(:approve_article) || !helpdesk_approval.approver?(User.current.id)))
        helpdesk_approval.destroy
      end
    end

    def clear_approvals(item)
      item.article.clear_approvals if Account.current.article_approval_workflow_enabled?
    end

    def content_changed?(item)
      item.changes.key?(:title) || item.draft_body.previous_changes.key?(:description)
    end
end
