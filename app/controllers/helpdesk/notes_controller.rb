class Helpdesk::NotesController < ApplicationController

  before_filter { |c| c.requires_permission :manage_tickets }

  before_filter :load_parent_ticket_or_issue

  include HelpdeskControllerMethods
  
protected

  def scoper
    @parent.notes
  end

  def item_url
    @parent
  end

  def process_item

    if @parent.is_a? Helpdesk::Ticket
      Helpdesk::TicketNotifier.send_later(:deliver_reply, @parent, @item) unless @item.private
      @parent.responder ||= current_user
      @parent.create_activity(current_user, "{{user_path}} added a {{comment_path}} to the ticket {{notable_path}}", 
                    {'eval_args' => {'comment_path' => ['comment_path', {
                                                        'ticket_id' => @parent.display_id, 
                                                        'comment_id' => @item.id}]}})
    end

    if @parent.is_a? Helpdesk::Issue
      unless @item.private
        @parent.tickets.each do |t|
          t.notes << (c = @item.clone)
          Helpdesk::TicketNotifier.deliver_reply(t, c)
        end
      end
      @parent.owner ||= current_user  if @parent.respond_to?(:owner)
    end

    @parent.save
  end

  def create_error
    redirect_to @parent
  end

end
