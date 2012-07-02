class Mobile::TicketsController < ApplicationController  
  include Helpdesk::TicketsHelper
  include Mobile::MobileHelperMethods

  #before_filter { |c| c.requires_permission :manage_tickets }
  before_filter :set_mobile
  before_filter :check_permistions, :only =>[:agent_view_list,:get_suggested_solutions,:requester_info]
  #FILTER_NAMES = [:open, :on_hold, :due_today, :new, :all_tickets]
  FILTER_NAMES = [:all_tickets]

  CUSTOMER_FILTER_NAMES = [:all_tickets,:open_or_pending,:resolved_or_closed]

  def check_permistions 
    requires_permission :manage_tickets
  end 

  def view_list
    agent_view_list if current_user.agent?
    customer_view_list if current_user.customer?
  end

  def customer_view_list
    view_list = []
    CUSTOMER_FILTER_NAMES.each { |view_name|
      count = TicketsFilter.filter(view_name.to_sym, current_user, current_user.tickets).length
      view_list.push( 
        :id => view_name, 
        :name => t("helpdesk.tickets.views.#{view_name}"), 
        :type => :filter, 
        :count =>  count
      )
    }
    render :json => view_list.to_json
  end

  def agent_view_list
    #Loading custom views
    view_list = []
    views = current_account.ticket_filters.my_ticket_filters(current_user)
    view_list.concat( views.map { |view| 
      view.deserialize_from_params(view.data)
      filter_id = view[:id]
      filter_name = view[:name]
      ticket_count =  current_account.tickets.permissible(current_user).count(:id, :conditions=> view.sql_conditions)
      { :id => filter_id, 
        :name => filter_name, 
        :type => :view, 
        :count=> ticket_count
      } 
    })
    #Fallback incase all custom views has 0 count..
    FILTER_NAMES.each { |view_name|
      view_list.push( :id => view_name, :name => t("helpdesk.tickets.views.#{view_name}"), 
        :type => :filter, :count => filter_count(view_name) )
    } 
    render :json => view_list.to_json
  end

  def get_portal
    #do it in better way..
    mob_json = current_account.to_mob_json(current_user.agent?)[0..-2]+","+current_user.to_mob_json[1..-1]
    render :json => mob_json
  end

  def get_suggested_solutions
    item = current_account.tickets.find_by_display_id(params[:id]) 
    Solution::Article.suggest_solutions item
    render :json => Solution::Article.suggest_solutions(item).to_json({:only=> [:id,:title,:desc_un_html]})
  end
  
  def ticket_properties
    is_new =  params[:id].nil?
    @item = current_account.tickets.find_by_display_id(params[:id]) unless params[:id].nil?
    @fields = []
    all_fields = current_portal.customer_editable_ticket_fields if current_user.customer?
    all_fields = current_account.main_portal.ticket_fields if current_user.agent?
    all_fields.each do |field|
        if field.visible_in_view_form? || is_new
              field_value = (field.is_default_field?) ? @item[field.field_name] : @item.get_ff_value(field.name) unless @item.nil?
              dom_type    = (field.field_type == "default_source") ? "dropdown" : field.dom_type
              puts "#{field.field_type == 'default_source'}, #{dom_type}"
              if(field.field_type == "nested_field" && !@item.nil?)
                field_value = {}
                field.nested_levels.each do |ff|
                  field_value[(ff[:level] == 2) ? :subcategory_val : :item_val] = @item.get_ff_value(ff[:name])
                end
                field_value.merge!({:category_val => @item.get_ff_value(field.name)})
              end
              field[:nested_choices] = field.nested_choices
              field[:nested_levels] = field.nested_levels
              field[:field_value] = field_value 
              field[:choices] = field.choices #TODO try to use to_json 
              field[:domtype] = dom_type
              field[:is_default_field] = field.is_default_field?
              field[:field_name] = field.field_name
              @fields.push(field)
        end
    end
    render :json => @fields.to_json
  end

  def requester_info
    item = current_account.tickets.find_by_display_id(params[:id])
    user = item.requester
    options = { :methods => [:avatar_url,:recent_tickets] }
    user_json = user.to_json(options)
    user_json.sub!("{\"user\":{","{\"user\":{\"success\":\"true\",")
    render :json => user_json[8..-2]
  end

end
