module ControllerMethods::BulkActionMethods

  private

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

    def destroy_item(item)
      if item.respond_to?(:deleted)
        item.deleted =  true
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

    def render_bulk_action_response(succeeded, errors)
      if errors.any?
        render_partial_success(succeeded, errors)
      else
        head 204
      end
    end
end