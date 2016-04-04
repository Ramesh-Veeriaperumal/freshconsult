class Freshfone::CallerController < ApplicationController

before_filter :update_caller_type, :only => [:block, :unblock] 

def block
  if @caller.save
    flash[:notice] = t('flash.freshfone.number.add_blacklist_success')
  else
    flash[:notice] = t('flash.freshfone.number.add_blacklist_failure')
  end
  respond_to do |format|
    format.js { }
  end
end

def unblock
  
  if @caller.save  
    flash[:notice] = t('flash.freshfone.number.remove_blacklist_success')
  else
    flash[:notice] = t('flash.freshfone.number.remove_blacklist_failure')
  end
  respond_to do |format|
    format.js { }
  end
end

private
 def update_caller_type
  type = (params[:action]== "unblock") ? 0 : 1
  @caller = current_account.freshfone_callers.find_by_id(params[:caller][:id])
  @caller.caller_type = type
 end

end

