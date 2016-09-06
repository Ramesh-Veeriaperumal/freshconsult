module DeleteSpamConcern
  extend ActiveSupport::Concern
  include BulkActionConcern

  def bulk_delete
    bulk_action do
      @items_failed = []
      @items.each do |item|
        @items_failed << item unless destroy_item(item)
      end
    end
  end

  def bulk_spam
    bulk_action do
      @items_failed = []
      @items.each do |item|
        @items_failed << item unless spam_item(item)
      end
    end
  end

  def destroy
    return head 204 if destroy_item(@item)
    render_errors(@item.errors) if @item.errors.any?
    head 404
  end

  def spam
    return head 204 if spam_item(@item)
    render_errors(@item.errors) if @item.errors.any?
    head 404
  end

  private

    def destroy_item(item)
      return false if spam_or_deleted?(item)
      if item.respond_to?(:deleted)
        item.deleted = true
        store_dirty_tags(item) if item.is_a?(Helpdesk::Ticket)
        item.save
      else
        item.destroy
      end
    end

    def spam_item(item)
      return false if spam_or_deleted?(item)
      item.spam = true
      store_dirty_tags(item)
      item.save
    end

    def spam_or_deleted?(item)
      (item.respond_to?(:deleted) && item.deleted) || (item.is_a?(Helpdesk::Ticket) && item.spam)
    end
end
