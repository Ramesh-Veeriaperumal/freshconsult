#--
# Copyright (c) 2010 Michael Berkovich, Geni Inc
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

class Wf::FilterController < ApplicationController
  
  before_filter { |c| c.requires_permission :manage_tickets }
  
  before_filter :chk_usr_permission, :only => [:delete_filter,:update_filter]
  
  def index
    @edit_filters = []
    view_filters = scoper.my_ticket_filters(current_user)
    view_filters.each do |filter|
      if (filter.accessible.user_id == current_user.id) or current_user.admin?
        @edit_filters.push(filter)
      end
    end
    
  end
 
  def chk_usr_permission 
     @wf_filter = current_account.ticket_filters.find_by_id(params[:id])
     if @wf_filter and @wf_filter.accessible.user_id != current_user.id and !current_user.admin? 
      flash[:notice] =  t(:'flash.general.access_denied')
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
     end
  end
  
  def update_filter
    @wf_filter.name = params[:filter_name]
    @wf_filter.visibility = params[:visibility]
    @wf_filter.save
  end
  
  def save_filter
    params.delete(:wf_id)
    
    wf_filter = Helpdesk::Filters::CustomTicketFilter.deserialize_from_params(params)
    wf_filter.visibility = params[:visibility]
    wf_filter.account_id = current_account.id
    wf_filter.validate!
    err_str = ""
    if wf_filter.errors?
      wf_filter.errors.each do |name,value|
        err_str << "#{name}  #{value} <br />"  
      end
    else  
      wf_filter.save
    end
    wf_filter.key = wf_filter.id.to_s 
    
    unless err_str.empty?
      flash[:error] = err_str
    else
      flash[:notice] = t(:'flash.filter.save_success')
    end
    
    render :partial => "save_filter",  :locals => { :redirect_path => helpdesk_filter_view_custom_path(wf_filter.key) }
  end

  def delete_filter
     if @wf_filter
       @wf_filter.destroy
       flash[:notice] = t("flash.filter.delete_success")
     end
    redirect_to :back
  end
  
  protected
  
  def scoper
    current_account.ticket_filters
  end

end
