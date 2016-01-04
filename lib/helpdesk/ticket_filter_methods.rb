# encoding: utf-8
module Helpdesk::TicketFilterMethods

  include TicketsFilter

  ORDER = {
    :defaults => [:save_as, :cancel],
    :userdefined_views => [:save, :cancel, :save_as, :edit, :delete ],
  }

  def top_views(selected = "new_and_my_open", dynamic_view = [], show_max = 1)

    default_views = fetch_default_views
    top_views_array = [].concat(split_and_arrange_views(dynamic_view)).concat(default_views)
    selected_item =  top_views_array.select { |v| v[:id].to_s == selected.to_s }.first

    if selected_item.blank?
      selected_from_default = (selected.blank? ? nil : SELECTORS.select { |v| v.first == selected.to_sym })
      if !params[:report_type].blank? || !params[:filter_type].blank?
        selected_from_default = SELECTORS.select { |v| v.first == :untitled_view }
      end
      selected_item = selected_from_default.blank? ?
                      (default_views.first) :
                      (selected_from_default.map { |i| { :id => i[0], :name => i[1], :default  =>  true} }.first)
    end

    top_view_html = drop_down_views(top_views_array, selected_item, "leftViewMenu", (selected.blank? or params[:unsaved_view])).to_s +
      controls_on_privilege(selected_item, (selected_item[:default]))
  end

  # Adding a divider to separate Archive, Spam and Trash from other views
  def fetch_default_views
    default_views = TicketsFilter.default_views
    insert_separator_at = default_views.index(default_views.find{ |f| /monitored_by/ =~ f[:id] }) + 1
    default_views.insert(insert_separator_at, { :id => :freshdesk_view_seperator })
  end

  # Get User created views and default views from dynamic views
  def split_and_arrange_views dynamic_view
    uneditable_views = []
    editable_views = []
    dynamic_view.each do |view|
      if can_manage?(view)
        editable_views << view
      else
        uneditable_views << view
      end
    end
    reordered_view(editable_views, uneditable_views)
  end

  # Add a divider between User created views and default views
  def reordered_view editable_views, uneditable_views
    unless editable_views.empty?
      editable_views.concat([{ :id => :freshdesk_view_seperator }]).concat(uneditable_views)
    else
      uneditable_views
    end
  end

  def drop_down_views(viewlist, selected_item, menuid = "leftViewMenu", unsaved_view=false)
    extra_class = ""
    extra_class = "unsaved" if unsaved_view
    unless viewlist.empty?
      more_menu_drop =
        content_tag(:div, (link_to strip_tags(selected_item[:name]).html_safe, helpdesk_tickets_path, {
                                :class => "drop-right nav-trigger #{extra_class}",
                                :menuid => "##{menuid}",
                                :id => "active_filter"
                            } ), :class => "link-item" ) +
        content_tag(:div, viewlist.map { |s| view_menu_links(s, "", (s[:id].to_s == selected_item[:id].to_s)) }.to_s.html_safe, :class => "fd-menu", :id => menuid)
    end
    more_menu_drop.html_safe
  end

  def view_menu_links( view, cls = "", selected = false )
    unless(view[:id] == :freshdesk_view_seperator)
      link_to( ((content_tag(:span, "", :class => "icon ticksymbol") if selected).to_s + strip_tags(view[:name])).html_safe,
                  filter_path(view),
                  :class => "#{selected ? 'active' : ''} #{cls}",
                  :rel => view[:default] ? "default_filter" : "" ,
                  :"data-pjax" => "#body-container",
                  :"data-parallel-url" => filter_parallel_path(view),
                  :"data-parallel-placeholder" => "#ticket-leftFilter"
              )
    else
      content_tag(:span, "", :class => "seperator")
    end
  end

  def filter_path view
    if view[:id] == "archived"
      helpdesk_archive_tickets_path
    else
      view[:default] ? helpdesk_filter_view_default_path(view[:id]) : helpdesk_filter_view_custom_path(view[:id])
    end
  end

  def filter_parallel_path view
    filter_options_helpdesk_tickets_path({
      (view[:default] ? 'filter_name' : 'filter_key') => view[:id]
    })
  end

  # Show appropriate links for User created views and default views
  def controls_on_privilege view, default=true
    control_links = ""

    order_of(view, default).each do |link_method|
      control_links << send("#{link_method}_link", view)
    end

    (content_tag :div, control_links.html_safe, :id => "view_manage_links").html_safe
  end

  # Get the ordering of links for User created views and default views
  def order_of view, default
    (default || !can_manage?(view)) ? ORDER[:defaults] : ORDER[:userdefined_views]
  end

  def can_manage? view
    return false unless view[:id].is_a? Numeric
    privilege?(:view_admin) or view[:user_id] == current_user.id
  end

  def save_link view
    link_to(link_title('save'), '#', :class => "hide", :id => "save_filter")
  end

  def cancel_link view
    unless params[:report_type].blank?
      view = current_filter
      view = {:default => view, :id => view} if view.is_a?(String)
    end
    link_to(link_title('cancel'), filter_path(view),
                                :class => "hide", :id => "cancel_filter",
                                :"data-parallel-placeholder" => "#ticket-leftFilter",
                                :"data-parallel-url" => filter_parallel_path(view),
                                :"data-pjax" => "#body-container"
                              )
  end

  def save_as_link view
    link_to(link_title("saveas"), custom_view_save_helpdesk_tickets_path({:operation => "save_as"}),
                                    filter_dialog_params.merge({
                                    :class => "hide", :id => "save_as_filter",
                                    :"data-title" => t("tickets_filter.saveas_tooltip").html_safe
                                  }))
  end

  def edit_link view
    link_to(link_title("edit"), custom_view_save_helpdesk_tickets_path({:operation => 'edit'}),
                                  filter_dialog_params.merge({
                                  :id => "edit_filter",
                                  :"data-title" => t("tickets_filter.edit_tooltip").html_safe
                                }))
  end

  def filter_dialog_params
    {
      :rel => "freshdialog",
      :"data-target" => "#filter_div",
      :"data-width" => "525px",
      :"data-submit-label" => t("save").html_safe,
      :"data-close-label" => t("cancel").html_safe,
      :"data-submit-loading" => t("saving").html_safe
    }
  end

  def delete_link view
    link_to(link_title('delete'), {
                                :controller => "wf/filter",
                                :action => "delete_filter", :id => view[:id]
                              }, {
                                :id => 'delete_filter',
                                :method => :delete,
                                :confirm => t("wf.filter.view.delete").html_safe
                              })
  end

  def link_title link_type
    content_tag(:i, "", {
                      :title => t("tickets_filter.#{link_type}_tooltip"),
                      :class => "ticket-view-#{link_type} tooltip",
                      :"data-placement" => "below"
                    }).html_safe
  end

  def filter_select( prompt = t('helpdesk.tickets.views.select'))
    selector = select("select_view", "id", SELECTORS.collect { |v| [v[1], helpdesk_filter_tickets_path(filter(v[0]))] },
              {:prompt => prompt}, { :class => "customSelect" })
  end

  def filter(selector = nil)
    selector ||= current_selector
  end

  def filter_count(selector=nil, unresolved=false)
    if Account.current.launched?(:es_count_reads)
      TicketsFilter.es_filter_count(selector, unresolved)
    else
      filter = TicketsFilter.filter(filter(selector), current_user, current_account.tickets.permissible(current_user))
      Sharding.run_on_slave do
        unresolved ? filter.unresolved.count : filter.count
      end
    end
  end

  def current_filter
    stored_key = params[:filter_key] || params[:filter_name]
    #To avoid setting the filter name to "Archived" as we don't store archived filter in cookies
    stored_key = "new_and_my_open" if stored_key == "archived"

    cookies[:filter_name] = (stored_key ? stored_key : (!cookies[:filter_name].blank?) ? cookies[:filter_name] : "new_and_my_open" )
  end

  def current_wf_order
    return @cached_filter_data[:wf_order].to_sym if @cached_filter_data && !@cached_filter_data[:wf_order].blank?
    cookies[:wf_order] = (params[:wf_order] ? params[:wf_order] : ( (!cookies[:wf_order].blank?) ? cookies[:wf_order] : DEFAULT_SORT )).to_sym
  end

  def current_wf_order_type
    return @cached_filter_data[:wf_order_type].to_sym if @cached_filter_data && !@cached_filter_data[:wf_order_type].blank?
    # return @cached_filter_data[:wf_order_type].to_sym if @cached_filter_data && !@cached_filter_data[:wf_order_type].blank?
    cookies[:wf_order_type] = (params[:wf_order_type] ? params[:wf_order_type] : ( (!cookies[:wf_order_type].blank?) ? cookies[:wf_order_type] : DEFAULT_SORT_ORDER )).to_sym
  end

  def current_selector
    current_filter#.reject { |f| CONTEXTS.include? f }
  end

  def filter_title(selector) # Possible dead code
    SELECTOR_NAMES[selector]
  end

  def current_filter_title # Possible dead code
    filter_title(current_selector)
  end

  def get_ticket_show_params(params, ticket_display_id) # Possible dead code
    filters = {:filters => params.clone}

    if filters[:filters].blank?
      show_params = {:id=>ticket_display_id}
    else
      filters[:filters].delete("action")
      filters[:filters].delete("controller")
      filters[:filters].delete("page")
      show_params = filters.merge!({:id=>ticket_display_id})
    end
    show_params
  end

end
