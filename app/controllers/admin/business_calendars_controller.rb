class Admin::BusinessCalendarsController < ApplicationController
  
  before_filter :set_selected_tab
  
  def index
    @business_calendars = BusinessCalendar.find(:first ,:conditions =>{:account_id => current_account.id})
     respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :json => @business_calendars }
    end
  end

  def show
  end

  def new
  end

  def edit
  end

  def create
  end

  def update
    redirect_back_or_default :action => 'index'
  end

  def destroy
  end

protected

def set_selected_tab
      @selected_tab = 'Admin'
end

end
