# encoding: utf-8
require "open-uri"

module HelpdeskControllerMethods
  include Helpdesk::NoteActions
  include CloudFilesHelper
  include Helpdesk::Permissions

  def self.included(base)
    base.send :before_filter, :build_item,          :only => [:new, :create]
    base.send :before_filter, :load_item,           :only => [:show, :edit, :update ]
    base.send :before_filter, :load_multiple_items, :only => [:destroy, :restore]
    base.send :before_filter, :add_to_history,      :only => [:show]
  end

  def create
    build_attachments @item, nscname
    if @item.save
      post_persist
    else
      create_error
    end
  end

  def post_persist #Need to check whether this should be called only inside create by Shan to do
    #create_attachments
    if @item.is_a?(Helpdesk::Ticket) and @item.outbound_email?
      flash[:notice] = I18n.t('flash.general.create.compose_email_success')
    else
      flash[:notice] = I18n.t(:'flash.general.create.success', :human_name => cname.humanize.downcase)
    end
    process_item #
    options = {}
    options.merge!({:human=>true}) if(!params[:human].blank? && params[:human].to_s.eql?("true"))  #to avoid unneccesary queries to users
    #redirect_back_or_default redirect_url
    if @item.is_a?(Helpdesk::Ticket) && params[:action] == "create" && @item.restricted_in_helpdesk?(current_user)
      helpdesk_restricted_access_redirection(@item, 'flash.agent_as_requester.ticket_create')
    else
      respond_to do |format|
        format.html { redirect_to params[:redirect_to].present? ? params[:redirect_to] : item_url }
        format.xml  { render :xml => @item.to_xml(options), :status => :created, :location => url_for(@item) }
        format.widget {render :action=>:create_ticket_status, :layout => "widgets/contacts"}
        format.js
        format.mobile {
          render :json => {:success => true,:item => @item , :success_message => I18n.t(:'flash.general.create.success', :human_name => cname.humanize.downcase)}.to_json
        }
        format.json {
          render :json => @item.to_json(options)
        }
      end
    end
  end

  def create_error
    respond_to do |format|
      format.html { render :action => :new }
      format.xml  { render :xml => @item.errors }
      format.widget {
        flash[:error] = "Error in creating the ticket. Try again later."
        render :action=>:create_ticket_status, :layout => "widgets/contacts"
      }
      format.mobile {
        render :json => { :failure => true, :errors => @item.errors.fd_json }
      }
      format.all {# TODO-RAILS3
        render :text => " ", :status => 406
      }
    end
  end

  def update
    if @item.update_attributes(params[nscname])
      post_persist
      flash[:notice] = I18n.t(:'flash.general.update.success', :human_name => cname.humanize.downcase)
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

    options = params[:basic].blank? ? {:basic=>true} : params[:basic].to_s.eql?("true") ? {:basic => true} : {}
    respond_to do |expects|
      expects.html do
        process_destroy_message
        redirect_to after_destroy_url
      end
      expects.mobile{
        render :json => {:success => true}
      }
      expects.nmobile{
        render :json => {:success => true}
      }
      expects.json  { render :json => :deleted}
      expects.js {
        process_destroy_message
        after_destroy_js
      }
      #until we impl query based retrieve we show only limited data on deletion.
      expects.xml{ render :xml => @items.to_xml(options)}
    end

  end

  def restore
    @items.each do |item|
      item.update_attribute(:deleted, false)
    end
    options = params[:basic].blank? ? {:basic=>true} : params[:basic].to_s.eql?("true") ? {:basic => true} : {}

    respond_to do |result|
      result.html{
        flash[:notice] = render_to_string(
          :partial => '/helpdesk/shared/flash/restore_notice', :contacts => @items).html_safe
        redirect_to after_restore_url
      }
      result.mobile { render :json => { :success => true }}
      result.nmobile { render :json => { :success => true }}
      result.xml {  render :xml => @items.to_xml(options) }
      result.json {  render :json => @items.to_json(options) }
      result.js {
        flash[:notice] = render_to_string(
          :partial => '/helpdesk/shared/flash/restore_notice', :contacts => @items).html_safe
      }
    end
  end

  def autocomplete #Ideally account scoping should go to autocomplete_scoper -Shan (POSSIBLE DEAD CODE)
    items = autocomplete_scoper.find(
      :all,
      :conditions => ["#{autocomplete_field} like ? and account_id = ?", "%#{params[:v]}%", current_account],
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
    @temp_item = scoper.find_by_id(id.to_i)

    #by Shan new
    raise(ActiveRecord::RecordNotFound) if (@temp_item.respond_to?('account_id=') && @temp_item.account_id != current_account.id)
    @temp_item
  end

  def load_item
    @item = self.instance_variable_set('@' + cname, load_by_param(params[:id]))
    #raise(ActiveRecord::RecordNotFound) if (@item.respond_to?('account_id=') && @item.account_id != current_account.id)
    #by Shan temp
    @item || raise(ActiveRecord::RecordNotFound)
  end

  def load_items
    if params[:ids]
      @items = cname.classify.eql?("Ticket") ? scoper.find_all_by_param(params[:ids]) : scoper.find_all_by_id(params[:ids])
      self.instance_variable_set('@' + cname.pluralize, @items)
    else
      load_multiple_items
    end
  end

  def load_multiple_items
    @items = (params[:ids] || Array.wrap(params[:id])).map { |id| load_by_param(id) }.select{ |r| r }
    self.instance_variable_set('@' + cname.pluralize, @items)
  end

  def build_item
    logger.debug "testing the caller class:: #{nscname} and cname::#{cname}"
    @item = self.instance_variable_set('@' + cname,
      scoper.is_a?(Class) ? scoper.new(params[nscname]) : scoper.build(params[nscname]))
    set_item_user

    @item
  end

  def set_item_user
    @item.account_id ||= current_account.id if (@item.respond_to?('account_id='))
    @item.user ||= current_user if (@item.respond_to?('user=') && !@item.user_id)
  end

  def process_item
    # Hook for controllers to add post create/update code
  end

  def process_destroy_message
    flash[:notice] = render_to_string(:partial => '/helpdesk/shared/flash/delete_notice').html_safe
    # Hook for controllers to add their own message and redirect
  end

  def load_parent_ticket # possible dead code
    @parent = Helpdesk::Ticket.find_by_param(params[:ticket_id], current_account)
    raise ActiveRecord::RecordNotFound unless @parent
  end

  def load_parent_ticket_or_issue
    @parent = Helpdesk::Ticket.find_by_param(params[:ticket_id], current_account) if params[:ticket_id]
    @parent = Helpdesk::Issue.find_by_id(params[:issue_id]) if params[:issue_id]
    raise ActiveRecord::RecordNotFound unless @parent
  end

  def optionally_load_parent
    @parent = Helpdesk::Ticket.find_by_param(params[:ticket_id], current_account)
  end

  def build_attachments item, model_name
    attachment_builder(item, params[model_name][:attachments], params[:cloud_file_attachments] )
    build_shared_attachments item
  end

  def build_shared_attachments item
      (params[:shared_attachments] || []).each do |r|
        a=Helpdesk::Attachment.find(r)
        item.shared_attachments.build(:account_id => item.account_id,:attachment=>a )
      end

      if !params[:admin_canned_responses_response].nil?
      (params[:admin_canned_responses_response][:attachments]).each do |a|
        attachment_created=item.account.attachments.create(:content => a[:resource], :description => a[:description],:attachable_type=>"Account", :attachable_id=>current_account.id)
        item.shared_attachments.build(:attachment=>attachment_created )
      end
      end
 end

  def item_url
    @item
  end

  def after_destroy_url
    :back
  end

  def after_destroy_js
    render(:update) { |page|
      @items.each { |i| page.visual_effect('fade', dom_id(i)) }
      if @cname == "note"
        page << "trigger_event('note_deleted', #{to_event_data(@items[0])});"
        page << "if(document.getElementById('cnt-reply-quoted')){"
        page.replace_html 'cnt-reply-quoted', h(quoted_text(@parent)) if @parent
        page << "}"
      elsif @cname == "attachment" || @cname == "cloud_file"
        attachment = @items.first
        attachment_details = ticket_page_attachment(attachment)
        if attachment_details
          if attachment_details[:attachments_count] > 0
            page.replace_html "#{attachment_details[:type]}_attachments_title_#{attachment_details[:id]}",
                              pluralize(attachment_details[:attachments_count],
                                        "Attachment")
          else
            page.replace_html "#{attachment_details[:type]}_attachments_container_#{attachment_details[:id]}", ""
          end
        end

        if @items.present?
          page << "trigger_event('attachment_deleted', {attachment_id: #{@items[0].id}, attachment_type: '#{@items[0].class.name.split('::')[1].underscore}'});"
        end
      end
      show_ajax_flash(page)
    }
  end

  def after_restore_url
    return :back if params[:redirect_back] or @items.size>1
    return @items.first if @items.size == 1
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
      history.shift if history.size > 4
      history << page
      session[:helpdesk_history] = history
    end
  end

  def fetch_item_attachments
    return unless @item.is_a? Helpdesk::Note and @item.fwd_email?
    (params[nscname][:attachments] || []).each do |a|
      begin
        if a[:resource].is_a?(String) and Integer(a[:resource]) # In case of forward, we are passing existing Attachment ID's to upload the file via URL's
          attachment_obj = current_account.attachments.find_by_id(a[:resource])
          url = attachment_obj.authenticated_s3_get_url
          io  = open(url)
          if io
            def io.original_filename; base_uri.path.split('/').last.gsub("%20"," "); end
          end
          a[:resource] = io
        end
        rescue Exception => e
          NewRelic::Agent.notice_error(e)
          Rails.logger.error("Error while fetching item attachments using ID")
      end
    end
  end

  def filter_params_ids
    if current_user.group_ticket_permission
      params[:ids] = current_account.tickets.group_tickets_permission(current_user, params[:ids] || params[:id]).collect(&:display_id)
    elsif current_user.assigned_ticket_permission
      params[:ids] = current_account.tickets.assigned_tickets_permission(current_user, params[:ids] || params[:id]).collect(&:display_id)
    end
  end

  def scoper_user_filters
    current_account.ticket_filters.my_ticket_filters(current_user)
  end

  def helpdesk_restricted_access_redirection(ticket, msg)
    view_on_portal_msg = I18n.t('flash.agent_as_requester.view_on_portal', :support_ticket_link => ticket.support_ticket_path)
    redirect_msg =  "#{I18n.t(:"#{msg}")} #{view_on_portal_msg}".html_safe
    flash[:notice] = redirect_msg
    respond_to do |format|
        format.html { redirect_to helpdesk_tickets_url }
        format.xml  { render :xml => {:message => redirect_msg } }
        format.widget { render :text => redirect_msg }
        format.js
        format.mobile {
          render :json => {:message => redirect_msg }
        }
        format.json {
          render :json => {:message => redirect_msg }
        }
    end
  end

end
