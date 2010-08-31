module HelpdeskControllerMethods

  def self.included(base)
    base.send :before_filter, :build_item,          :only => [:new, :create]
    base.send :before_filter, :load_item,           :only => [:show, :edit, :update]
    base.send :before_filter, :load_multiple_items, :only => [:destroy, :restore]
    base.send :before_filter, :add_to_history,      :only => [:show]
  end
  

  def create
    if @item.save
      create_attachments
      process_item
      flash[:notice] = "The #{cname.humanize.downcase} has been created"
      redirect_to params[:redirect_to].present? ? params[:redirect_to] : item_url
    else
      create_error
    end
  end

  def create_error
    render :action => :new
  end

  def update
    if @item.update_attributes(params[nscname])
      create_attachments
      process_item
      flash[:notice] = "The #{cname.humanize.downcase} has been updated"
      redirect_to params[:redirect_to].present? ? params[:redirect_to] : item_url
    else
      edit_error
    end
  end

  def edit_error
    render :action => :edit
  end

  def destroy
    @items.each do |item|
      if item.respond_to?(:deleted)
        item.update_attribute(:deleted, true)
        @restorable = true
      else
        item.destroy
      end
    end

    respond_to do |expects|
      expects.html do 
        flash[:notice] = render_to_string(:partial => '/helpdesk/shared/flash/delete_notice') 
        redirect_to after_destroy_url
      end
      expects.js do
        render(:update) { |page| @items.each { |i| page.visual_effect('fade', dom_id(i)) } }
      end
    end

  end

  def restore
    @items.each do |item|
      item.update_attribute(:deleted, false)
    end

    flash[:notice] = render_to_string(
      :partial => '/helpdesk/shared/flash/restore_notice')

    redirect_to :back
  end

  def autocomplete
    items = autocomplete_scoper.find(
      :all, 
      :conditions => ["#{autocomplete_field} like ?", "%#{params[:v]}%"], 
      :limit => 30)

    r = {:results => items.map {|i| {:id => autocomplete_id(i), :value => i.send(autocomplete_field)} } } 

    respond_to do |format|
      format.json { render :json => r.to_json }
    end
  end


protected

  def scoper
    eval "Helpdesk::#{cname.classify}"
  end

  def cname
    @cname ||= controller_name.singularize
  end

  def nscname
    @nscname ||= controller_path.gsub('/', '_').singularize
  end

  def autocomplete_scoper
    scoper
  end

  def autocomplete_field
    "name"
  end

  def autocomplete_id(item)
    item.to_param
  end

  def load_by_param(id)
    scoper.respond_to?(:find_by_param) ?  scoper.find_by_param(id) : scoper.find_by_id(id.to_i)
  end

  def load_item
    @item = self.instance_variable_set('@' + cname, load_by_param(params[:id])) 
    @item || raise(ActiveRecord::RecordNotFound)
  end

  def load_multiple_items
    @items = (params[:ids] || (params[:id] ? [params[:id]] : [])).map { |id| load_by_param(id) }.select{ |r| r }
    self.instance_variable_set('@' + cname.pluralize, @items) 
  end

  def build_item
    @item = self.instance_variable_set('@' + cname,
      scoper.is_a?(Class) ? scoper.new(params[nscname]) : scoper.build(params[nscname]))
    set_item_user
    @item
  end

  def set_item_user
    @item.user ||= current_user if (@item.respond_to?('user=') && !@item.user_id)
  end

  def process_item
    # Hook for controllers to add post create/update code
  end

  def load_parent_ticket
    @parent = Helpdesk::Ticket.find_by_param(params[:ticket_id]) 
    raise ActiveRecord::RecordNotFound unless @parent
  end

  def load_parent_ticket_or_issue
    @parent = Helpdesk::Ticket.find_by_param(params[:ticket_id]) if params[:ticket_id]
    @parent = Helpdesk::Issue.find_by_id(params[:issue_id]) if params[:issue_id]
    raise ActiveRecord::RecordNotFound unless @parent
  end

  def optionally_load_parent
    @parent = Helpdesk::Ticket.find_by_param(params[:ticket_id]) 
  end
  
  def create_attachments
    return unless @item.respond_to?(:attachments)
    (params[nscname][:attachments] || []).each do |a|
      @item.attachments.create(:content => a[:file], :description => a[:description])
    end
  end

  def item_url
    @item
  end

  def after_destroy_url
    :back
  end

  def add_to_history(item = false, cls = false)
    item ||= @item

    return unless item.respond_to? :nickname

    page = {
      :title => item.nickname, 
      :url => {
        :controller => params[:controller],
        :action => params[:action],
        :id => item.to_param,
      },
      :class => cls || cname
    }

    history = session[:helpdesk_history] || []

    if not history.include? page
      history.shift if history.size > 2
      history << page
      session[:helpdesk_history] = history
    end
  end


end
