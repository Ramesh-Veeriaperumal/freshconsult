# encoding: utf-8
require "open-uri"

module HelpdeskControllerMethods
  include Helpdesk::NoteActions
  include CloudFilesHelper
  include Helpdesk::Permissible
  

  def self.included(base)
    base.send :before_filter, :build_item,          :only => [:new, :create]
    base.send :before_filter, :load_item,           :only => [:show, :edit, :update ]
    base.send :before_filter, :load_multiple_items, :only => [:destroy, :restore]
    # base.send :before_filter, :add_to_history,      :only => [:show]
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
    unless flash[:notice].present?
      if @item.is_a?(Helpdesk::Ticket) and @item.outbound_email?
        flash[:notice] = I18n.t('flash.general.create.compose_email_success')
      elsif @item.is_a?(Helpdesk::Ticket) and @item.tracker_ticket?
        flash[:notice] = I18n.t('flash.general.create.tracker_success')
      else
        flash[:notice] = I18n.t(:'flash.general.create.success', :human_name => cname.humanize.downcase)
      end
    end
    process_item #
    options = {}
    options.merge!({:human=>true}) if(!params[:human].blank? && params[:human].to_s.eql?("true"))  #to avoid unneccesary queries to users
    #redirect_back_or_default redirect_url
    if @item.is_a?(Helpdesk::Ticket) && params[:action] == "create" && !api_request? && @item.restricted_in_helpdesk?(current_user)
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
        item.deleted =  true
        @restorable = true
        store_dirty_tags(item) if item.is_a?(Helpdesk::Ticket)
        item.save
      else
        item.destroy
      end
      Search::RecentTickets.new(item.display_id).delete if item.is_a?(Helpdesk::Ticket)
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
      item.deleted = false
      restore_dirty_tags(item) if item.is_a?(Helpdesk::Ticket)
      item.save
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

  def check_domain_exists
    if @company.errors && @company.errors[:"company_domains.domain"].include?("has already been taken")
      @company.company_domains.each do |cd|
        @existing_company ||= current_account.company_domains.find_by_domain(cd.domain).try(:company) if cd.new_record?
      end
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
      @items = cname.classify.eql?('Ticket') ? scoper.where(display_id: params[:ids]).to_a : scoper.where(id: params[:ids]).to_a
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
    raise ActiveRecord::RecordNotFound unless @parent
  end

  def optionally_load_parent
    @parent = Helpdesk::Ticket.find_by_param(params[:ticket_id], current_account)
  end

  def build_attachments item, model_name
    attachment_builder(item, params[model_name][:attachments], params[:cloud_file_attachments], params[:attachments_list])
    build_shared_attachments item
  end

  def build_shared_attachments item
      if params[:shared_attachments].present?
        uniq_shared_attachments=params[:shared_attachments].uniq
        (uniq_shared_attachments || []).each do |r|
          a=current_account.attachments.find(r)
          item.shared_attachments.build(:attachment=>a)
        end
      end
      unless params[:admin_canned_responses_response].nil?
        (params[:admin_canned_responses_response][:attachments]).each do |a|
          attachment_created=item.account.attachments.create(:content => a[:resource], :description => a[:description],:attachable_type=> "Account", :attachable_id=>current_account.id)
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
          # for edit note
          @drop_id = 0;
          if @cname == "cloud_file"
            @drop_id = @items[0].droppable_id;
          end
          page << "Helpdesk.MultipleFileUpload.manageNoteData('#{@cname}',#{@items[0].id},#{@drop_id})";
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
    return unless (@item.is_a? Helpdesk::Note ) or @item.is_a? Helpdesk::Ticket or @item.is_a? Helpdesk::TicketTemplate
    if params[:sol_articles_cloud_file_attachments].present?
      fetch_cloud_file_attachments
    end
    (params[nscname][:attachments] || []).each do |a|
      fetch_item_attcachments_using_id a
    end
  end

  def fetch_item_attcachments_using_id attachment
    begin
      if attachment[:resource].is_a?(String) and Integer(attachment[:resource]) # In case of forward, we are passing existing Attachment ID's to upload the file via URL's
        attachment_obj = current_account.attachments.find_by_id(attachment[:resource])
        return unless attachment_obj.present? && attachment_permissions(attachment_obj)
        attachment[:resource] = attachment_obj.to_io
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      Rails.logger.error("Error while fetching item attachments using ID")
    end
  end

  def fetch_cloud_file_attachments item = @item
    return unless (item.is_a? Helpdesk::Note ) or item.is_a? Helpdesk::Ticket or item.is_a? Helpdesk::TicketTemplate
    params[:sol_articles_cloud_file_attachments].each do |a|
      if a[:resource].present?
        attachment_obj = current_account.cloud_files.find_by_id(a[:resource])
        next unless attachment_obj.present? && attachment_permissions(attachment_obj)
        cloud_file_url = attachment_obj.url
        cloud_file_app_id = attachment_obj.application_id
        cloud_file_filename = attachment_obj.filename
        result = {:url => cloud_file_url, :filename => cloud_file_filename,:application_id => cloud_file_app_id}
        item.cloud_files.build(result)
      end
    end
  end

  # If there is any change in this method related to ticket permission,
  # Please change the same in api/tickets_controller#ticket_permission?
  def filter_params_ids
    if current_user.group_ticket_permission
      params[:ids] = current_account.tickets.group_tickets_permission(current_user, params[:ids] || params[:id]).collect(&:display_id).collect(&:to_s)
    elsif current_user.assigned_ticket_permission
      params[:ids] = current_account.tickets.assigned_tickets_permission(current_user, params[:ids] || params[:id]).collect(&:display_id).collect(&:to_s)
    end
  end

  def scoper_user_filters
    current_account.ticket_filters.my_ticket_filters(current_user)
  end

  def helpdesk_restricted_access_redirection(ticket, msg, full_message = "")
    view_on_portal_msg = I18n.t('flash.agent_as_requester.view_ticket_on_portal', :support_ticket_link => ticket.support_ticket_path)
    flash[:notice] = redirect_msg = full_message.presence || "#{I18n.t(:"#{msg}")} #{view_on_portal_msg}".html_safe
    redirect_params = {}
    respond_to do |format|
        format.html {
          redirect_params[:pjax_redirect] = true if request.headers['X-PJAX']
          redirect_to helpdesk_tickets_url(redirect_params)
        }
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

  def api_request?
    params[:format] == "json" || params[:format] == "xml"
  end

  def attachment_permissions(attach)
    attach.visible_to_me?
  end

end
