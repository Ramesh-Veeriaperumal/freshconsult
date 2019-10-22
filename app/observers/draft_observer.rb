class DraftObserver < ActiveRecord::Observer
  include Solution::ArticleVersioning
  observe Solution::Draft

  def after_save(item)
    return if !item.account.article_versioning_enabled? || item.false_delete_attachment_trigger
    item.cancelling ? version_discard_or_destroy(item) : version_create_or_update(item)
  end

  def after_destroy(item)
    version_discard_or_destroy(item) if item.account.article_versioning_enabled?
  end
end
