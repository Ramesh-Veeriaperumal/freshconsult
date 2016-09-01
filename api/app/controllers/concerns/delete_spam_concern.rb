module DeleteSpamConcern
  extend ActiveSupport::Concern
  include BulkActionConcern

  def bulk_delete
    bulk_action { destroy }
  end

  def bulk_spam
    bulk_action { spam }
  end

  def destroy
    @items_failed = []
    @items.each do |item|
      @items_failed << item if spam_or_deleted?(item) || !destroy_item(item)
    end
  end

  def spam
    @items_failed = []
    @items.each do |item|
      @items_failed << item if spam_or_deleted?(item) || !spam_item(item)
    end
  end

  private

    def destroy_item(item)
      if item.respond_to?(:deleted)
        item.deleted = true
        store_dirty_tags(item) if item.is_a?(Helpdesk::Ticket)
        item.save
      else
        item.destroy
      end
    end

    def spam_item(item)
      item.spam = true
      store_dirty_tags(item)
      item.save
    end

    def spam_or_deleted?(item)
      (item.respond_to?(:deleted) && item.deleted) || (item.is_a?(Helpdesk::Ticket) && item.spam)
    end
end
