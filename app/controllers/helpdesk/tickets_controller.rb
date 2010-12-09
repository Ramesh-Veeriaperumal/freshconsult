class Helpdesk::TicketsController < ApplicationController
  layout 'helpdesk/layout'


  before_filter { |c| c.requires_permission :manage_tickets }

  include HelpdeskControllerMethods

  before_filter :load_multiple_items, :only => [:destroy, :restore, :spam, :unspam, :assign]

  def index
   

    @items = Helpdesk::Ticket.filter(current_account, 
      params[:filters] || [:open, :unassigned],
      current_user
    )

    @items = Helpdesk::Ticket.search(@items, params[:f], params[:v])

    respond_to do |format|
      format.html  do
        @items = @items.paginate(
          :page => params[:page], 
          :order => Helpdesk::Ticket::SORT_SQL_BY_KEY[(params[:sort] || :created_asc).to_sym],
          :per_page => 10)
      end
      format.atom do
        @items = @items.newest(20)
      end
    end

  end


  def show
    @subscription = current_user && @item.subscriptions.find(
      :first, 
      :conditions => {:user_id => current_user.id})

    respond_to do |format|
      format.html  
      format.atom
    end
  end

  def update
    
    old_item = @item.clone
    if @item.update_attributes(params[nscname])

      if old_item.responder_id != @item.responder_id
        @item.create_status_note(current_account, "#{old_item.responder ? "Reassigned" : "Assigned"} to #{@item.responder ? @item.responder.name : "Nobody"}", current_user)
      end

      if old_item.status != @item.status
        @item.create_status_note(current_account, "Status changed to \"#{@item.status_name.titleize}\"", current_user)
      end

      flash[:notice] = "The #{cname.humanize.downcase} has been updated"
      redirect_to item_url
    else
      edit_error
    end
  end

  def assign
   
    user = params[:responder_id] ? User.find(params[:responder_id]) : current_user

    @items.each do |item|
      
      message = "#{item.responder ? "Reassigned" : "Assigned"} to #{user.name}"
      item.responder = user
      item.train(:ham)
      item.save
      item.create_status_note(current_account, message, current_user)
    end

    flash[:notice] = render_to_string(
      :inline => "<%= pluralize(@items.length, 'ticket was', 'tickets were') %> assigned to #{user.name}.")

    if user === current_user && @items.size == 1
      redirect_to helpdesk_ticket_path(@items.first)
    else
      redirect_to :back
    end
  end
  def spam
    @items.each do |item|
      item.train(:spam)
      item.save
    end

    flash[:notice] = render_to_string(
      :inline => "<%= pluralize(@items.length, 'ticket was', 'tickets were') %> flagged as spam. <%= link_to('Undo', { :action => :unspam, :ids => params[:ids] }, { :method => :put }) %>")

    redirect_to :back
  end

  def unspam
    @items.each do |item|
      item.train(:ham)
      item.save
    end

    flash[:notice] = render_to_string(
      :inline => "<%= pluralize(@items.length, 'ticket was', 'tickets were') %> removed from the spam folder.")

    redirect_to :back
  end

  def empty_trash
    Helpdesk::Ticket.destroy_all(:deleted => true)
    flash[:notice] = "All tickets in the trash folder were deleted."
    redirect_to :back
  end

  def empty_spam
    Helpdesk::Ticket.destroy_all(:spam => true)
    flash[:notice] = "All tickets in the spam folder were deleted."
    redirect_to :back
  end

protected

  def item_url
   
    return new_helpdesk_ticket_path if params[:save_and_create]
    @item
  end


  def process_item
  
    # Tickets created by staff have @item.source == 0
    if @item.source == 0
      @item.spam = false

      n = @item.notes.build(
        :user => @item.requester, #by Shan temp
        :account_id => current_account.id,
        :incoming => false,
        :private => true,
        :source => 2,
        :body => (!@item.description || @item.description.empty?) ? "Created by staff at #{Time.now}" : @item.description
      )

      n.save!
    end
   
  end

end
