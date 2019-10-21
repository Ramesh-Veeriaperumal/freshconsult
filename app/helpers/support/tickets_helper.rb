module Support::TicketsHelper

  TOOLBAR_LINK_OPTIONS = {  "data-remote" => true, 
                            "data-response-type" => "script",
                            "data-method" => :get,
                            "data-loading-box" => "#ticket-list" }
  ALL_COMPANIES_OPTION_THRESHOLD = 20

  def current_filter
    @current_filter ||= set_cookie :wf_filter, "open_or_pending"
  end

  def current_wf_order 
    @current_wf_order ||= set_cookie :wf_order, TicketsFilter::DEFAULT_PORTAL_SORT
  end

  def current_wf_order_type 
    @current_wf_order_type ||= set_cookie :wf_order_type, TicketsFilter::DEFAULT_PORTAL_SORT_ORDER
  end

  def current_requested_by
    session[:requested_by] = params[:requested_by].presence || session[:requested_by].presence || 0
  end

  def current_requested_by_company
    session[:requested_by_company] = params[:requested_by_company].presence || session[:requested_by_company].presence || default_company_id
  end

  # Will set a cookie until the browser cache is cleared
  def set_cookie type, default_value
    cookies[type] = (params[type] ? params[type] : ( (!cookies[type].blank?) ? cookies[type] : default_value )).to_sym
  end

  def visible_fields
    visible_fields = ["display_id", "status", "created_at", "updated_at", "requester_name"] # removed "due_by", "resolved_at"
    current_portal.ticket_fields(:customer_visible).each { |field| visible_fields.push(field.name) }
    visible_fields
  end

  def visible_fields_details
    current_portal.ticket_fields(:customer_visible)
  end

  def filter_list    
    f_list = [:all, :open_or_pending, :resolved_or_closed].map{ |f| 
                [ t("helpdesk.tickets.views.#{f}"), 
                  filter_support_tickets_path( :wf_filter => f, :requested_by => @requested_by),
                  (@current_filter == f)] }
    if current_account.features_included?(:archive_tickets)
      f_list << [:divider]                
      f_list << [t("helpdesk.tickets.views.archived"), 
                  filter_support_archive_tickets_path(:wf_filter => :archived, :requested_by => @requested_by),
                  (@current_filter == :archived)]
    end
    
    # Constructing the dropdown
    dropdown_menu f_list, TOOLBAR_LINK_OPTIONS
  end

  def user_list
    dropdown_menu [
      [t("tickets_filter.everyone_in_company", :company_name => @company.name), 
                    filter_support_tickets_path(:requested_by => 0), 
                    (@requested_by.to_i == 0)],
      [t("myself"), filter_support_tickets_path(:requested_by => current_user.id), 
                    (@requested_by.to_i == current_user.id)],
      [:divider]].concat(@filter_users.map{ 
                    |x| [ x.name, 
                          filter_support_tickets_path(:requested_by => x.id), 
                          (@requested_by.to_i == x.id) ] unless( current_user.id == x.id )
                    }), TOOLBAR_LINK_OPTIONS
  end

  def company_list
    all_companies_option = [[ t("tickets_filter.all_companies"), 
                             filter_support_tickets_path(:requested_by_company => 0),
                             (@requested_by_company == 0 ) ],[:divider]]
    companies_list = @companies.map{
                        |x| [ x.name,
                              filter_support_tickets_path(:requested_by_company => x.id,
                                                          :requested_by => 0),
                              (@requested_by_company.to_i == x.id) ]
                     }
    # Do not show all companies option when the number of companies for a contact
    # exceeds 20. When the contact is a  client manager for all the companies,
    # allowing all companies option will select all companies tickets and this may
    # have a impact in performance. 
    dropdown_options = if @companies.length > ALL_COMPANIES_OPTION_THRESHOLD
                      companies_list
                    else
                      all_companies_option.concat(companies_list)
                    end
    dropdown_menu dropdown_options, TOOLBAR_LINK_OPTIONS
  end

  def raised_by
    if @requested_by.to_i == 0
      t("tickets_filter.everyone_in_company", :company_name => @company.name)
    else
      @requested_item.name
    end
  end

  def raised_by_company
    if @requested_company.present?
      { :name => @requested_company.name, :id => @requested_company.id }
    else
      { :name => t("tickets_filter.all_companies"), :id => 0 }
    end
  end

  def raised_by_company_user
    if @requested_by.to_i == 0
      t("tickets_filter.everyone")
    else
      @requested_item.name
    end
  end

  def default_company_id
    current_user.company_id || 0
  end

  def ticket_sorting
    # Filtering out the visible sorting fields for portal and 
    # preping them for bootstrap dropdown as and array
    vfs = visible_fields
    sort_fields = TicketsFilter.sort_fields_options.map { |field|
                      [ field[0], 
                        filter_support_tickets_path(:wf_order => field[1]),
                        (field[1] == @current_wf_order) ] if vfs.include?(field[1].to_s)
                  }.push([:divider]) # Adding a divider that will show up under the sort list

    # Preping the ascending & decending orders for bootstrap dropdown as and array
    sort_order = TicketsFilter.sort_order_fields_options.map{ |so| 
                      [ so[0], 
                        filter_support_tickets_path(:wf_order_type => so[1]), 
                        (so[1] == @current_wf_order_type)] 
                  } 

    # Constructing the dropdown
    dropdown_menu sort_fields.concat(sort_order), TOOLBAR_LINK_OPTIONS
  end

end
