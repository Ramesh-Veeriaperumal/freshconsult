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
      Helpdesk::TicketNotifier.deliver_reply(@parent, @item) unless @item.private #by Shan using delay_jobs here..
      #Helpdesk::TicketNotifier.send_later(:deliver_reply, @parent, @item) unless @item.private
      @parent.responder ||= current_user
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
