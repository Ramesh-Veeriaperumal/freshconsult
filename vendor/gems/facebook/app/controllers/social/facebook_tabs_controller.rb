class Social::FacebookTabsController < ApplicationController

  before_filter { |c| c.requires_feature :facebook_page_tab }

  #Removing a Facebook Page Tab
  def remove
    page = current_account.facebook_pages.find(params[:facebook_id]) 
    fb_page_tab = Facebook::PageTab::Configure.new(page,"page_tab")
    if fb_page_tab.execute("remove")
      flash[:success] = t('facebook_tab.tab_removed')
    else
      flash[:error] = t('facebook_tab.tab_not_removed')
    end
    redirect_to :back
  end

end