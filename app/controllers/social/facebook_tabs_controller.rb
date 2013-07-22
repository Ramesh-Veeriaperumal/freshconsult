class Social::FacebookTabsController < ApplicationController

  before_filter :load_page

  def remove
    if fb_page_tab.remove
      flash[:success] = t('facebook_tab.tab_removed')
    else
      flash[:error] = t('facebook_tab.tab_not_removed')
    end
    redirect_to :back
  end
 
  private

    def load_page
      @page = current_account.facebook_pages.find(params[:facebook_id]) 
    end

    def fb_page_tab
      @fb_page_tab ||= FBPageTab.new @page
    end
end