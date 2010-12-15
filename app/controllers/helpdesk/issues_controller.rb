class Helpdesk::IssuesController < ApplicationController

  before_filter { |c| c.requires_permission :manage_tickets }

  include HelpdeskControllerMethods

  before_filter :load_item, :only => [:show, :edit, :update, :delete_all, :restore_all]

  before_filter :load_multiple_items, :only => [:destroy, :restore, :spam, :unspam, :assign]

  def index

    @items = Helpdesk::Issue.filter(
      params[:filters] || [:open, :visible],
      current_user
    )

    @items = Helpdesk::Issue.search(@items, params[:f], params[:v])

    respond_to do |format|
      format.html  do
        @items = @items.paginate(
          :page => params[:page], 
          :order => Helpdesk::Issue::SORT_SQL_BY_KEY[(params[:sort] || :created_asc).to_sym],
          :per_page => 10)
      end
      format.atom do
        @items = Helpdesk::Issue.visible.newest(20)
      end
    end

  end


  def show
    respond_to do |format|
      format.html  
      format.atom
    end
  end

  def update

    old_item = @item.clone
    if @item.update_attributes(params[nscname])

      if old_item.owner_id != @item.owner_id
        @item.create_status_note("#{old_item.owner ? "Reassigned" : "Assigned"} to #{@item.owner ? @item.owner.name : "Nobody"}", current_user)

        if params[:apply_to_all]
          @item.tickets.each do |t|
            t.update_attribute(:responder_id, @item.owner_id)
            t.create_status_note("Assigned (via Issue) to \"#{@item.owner ? @item.owner.name : "Nobody"}\"", current_user)
          end
        end
      end

      if old_item.status != @item.status
        @item.create_status_note("Status changed to \"#{@item.status_name.titleize}\"", current_user)
        if params[:apply_to_all]
          @item.tickets.each do |t|
            t.update_attribute(:status, @item.status)
            t.create_status_note("Status changed (via Issue) to \"#{@item.status_name.titleize}\"", current_user)
          end
        end
      end

      flash[:notice] = "The #{cname.humanize.downcase} has been updated"
      redirect_to item_url
    else
      edit_error
    end
  end

  def assign
    user = params[:owner_id] ? User.find(params[:owner_id]) : current_user

    @items.each do |item|
      message = "#{item.owner ? "Reassigned" : "Assigned"} to #{user.name}"
      item.owner = user
      item.save
      item.create_status_note(message, current_user)
    end

    flash[:notice] = render_to_string(
      :inline => "<%= pluralize(@items.length, 'issue was', 'issues were') %> assigned to #{user.name}.")

    if user === current_user && @items.size == 1
      redirect_to helpdesk_issue_path(@items.first)
    else
      redirect_to :back
    end
  end

  def empty_trash
    Helpdesk::Issue.destroy_all(:deleted => true)
    flash[:notice] = "All issues in the trash folder were deleted."
    redirect_to :back
  end

  def delete_all
    @item.update_attribute(:deleted, true)
    @item.tickets.each { |t| t.update_attribute(:deleted, true) }
    flash[:notice] = "This issue & all of its tickets were deleted."
    redirect_to item_url
  end

  def restore_all
    @item.update_attribute(:deleted, false)
    @item.tickets.each { |t| t.update_attribute(:deleted, false) }
    flash[:notice] = "This issue & all of its tickets were restored."
    redirect_to item_url
  end


protected

  def item_url
    return new_helpdesk_issue_path if params[:save_and_create]
    @item
  end

  def process_item
    # n = @item.notes.build(
      # :user => current_user,
      # :incoming => false,
      # :private => true,
      # :source => 2,
      # :body => (!@item.description || @item.description.empty?) ? "Created by staff at #{Time.now}" : @item.description
    # )

    # n.save!
   
  end

end
