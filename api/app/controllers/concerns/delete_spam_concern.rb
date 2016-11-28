module DeleteSpamConcern
  extend ActiveSupport::Concern
  include Helpdesk::TagMethods
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

  def bulk_restore
    bulk_action do
      @items_failed = []
      @items.each do |item|
        @items_failed << item unless restore_item(item)
      end
    end
  end

  def bulk_unspam
    bulk_action do
      @items_failed = []
      @items.each do |item|
        @items_failed << item unless unspam_item(item)
      end
    end
  end

  def destroy
    if destroy_item(@item)
      post_destroy_actions(@item)
      return head 204
    end
    return render_errors(@item.errors) if @item.errors.any?
    head 404
  end

  def spam
    return head 204 if spam_item(@item)
    return render_errors(@item.errors) if @item.errors.any?
    head 404
  end

  def restore
    return head 204 if restore_item(@item)
    return render_errors(@item.errors) if @item.errors.any?
    head 404
  end

  def unspam
    return head 204 if unspam_item(@item)
    return render_errors(@item.errors) if @item.errors.any?
    head 404
  end

  protected # Methods copied from lib/helpdesk_system.rb

    #Method to check permission for normal attachments & cloud_files destroy.
    def check_destroy_permission
      can_destroy = false
      model_name  = define_model

      @items.each do |file|
        file_type       = file.send("#{model_name}_type")
        file_attachable = file.send(model_name) unless ['UserDraft'].include? file_type

        if ['Helpdesk::Ticket', 'Helpdesk::Note'].include? file_type
          ticket = file_attachable.respond_to?(:notable) ? file_attachable.notable : file_attachable
          can_destroy = true if current_user and (ticket.requester_id == current_user.id or ticket_privilege?(ticket))
        elsif ['Solution::Article', 'Solution::Draft'].include? file_type
          can_destroy = true if privilege?(:publish_solution) or (current_user && file_attachable.user_id == current_user.id)
        elsif ['Account'].include? file_type
          can_destroy = true if privilege?(:manage_account)          
        elsif ['Post'].include? file_type
          can_destroy = true if privilege?(:edit_topic) or (current_user && file_attachable.user_id == current_user.id)
        elsif ['User'].include? file_type
          can_destroy = true if privilege?(:manage_users) or (current_user && file_attachable.id == current_user.id)
        elsif ['Helpdesk::TicketTemplate'].include? file_type
          can_destroy = true if template_priv? file_attachable
        elsif ['UserDraft'].include? file_type
          can_destroy = true if (current_user && file.attachable_id == current_user.id)
        end
        access_denied unless can_destroy
      end
    end

    def define_model
      if controller_name.eql?("attachments")
        "attachable"
      elsif controller_name.eql?("cloud_files")
        "droppable"
      else
        access_denied
      end
    end

    def template_priv? item
      privilege?(:manage_ticket_templates) or item.visible_to_only_me?
    end

    def ticket_privilege?(ticket)
      privilege?(:manage_tickets) && current_user.has_ticket_permission?(ticket)
    end

  private

    def destroy_item(item)
      # TODO-EMBERAPI "Deleted_at" not populated on User - use of field to be verified
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

    def restore_item(item)
      return false unless item.deleted
      item.deleted = false
      restore_dirty_tags(item) if item.is_a?(Helpdesk::Ticket)
      item.save
    end

    def unspam_item(item)
      return false unless item.spam
      item.spam = false
      restore_dirty_tags(item)
      item.save
    end

    def spam_or_deleted?(item)
      (item.respond_to?(:deleted) && item.deleted) || (item.is_a?(Helpdesk::Ticket) && item.spam)
    end

    def post_destroy_actions(item)
    end
end
