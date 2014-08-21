class Helpdesk::SubscriptionsController < ApplicationController

  include ActionView::Helpers::TextHelper

  before_filter :load_parent_ticket , :except => :unwatch_multiple
  before_filter :set_native_mobile, :only => [:create_watchers, :unwatch,:index]
  def index
    @ticket = @parent
    respond_to do |format|
      format.html do
        render :partial => "helpdesk/subscriptions/ticket_watchers"
      end
      format.nmobile do
         render :json => @ticket.subscriptions.map(&:user_id)
      end
    end 
  end

  def create_watchers
    @ticket = @parent
    if current_account.agents.find_by_user_id(params[:user_id])
      subscription = @ticket.subscriptions.build(:user_id => params[:user_id])
      if subscription.save
        if current_user.id != subscription.user_id
          Helpdesk::WatcherNotifier.send_later(:notify_new_watcher, 
                                               @ticket, 
                                               subscription, 
                                               "#{current_user.name}")
        end
	    respond_to do |format|
    	    format.html{render :nothing => true}
        	format.nmobile {render :json => { :success => true }.to_json }
    	end
      else
        render :json => { :success => false } 
      end
    end
  end

  def unwatch
    @ticket = @parent
    subscription = @ticket.subscriptions.find_by_user_id(current_user.id)
    subscription.destroy if subscription
    respond_to do |format|
		format.nmobile { render :json => { :success => true }.to_json }
        format.js { render :nothing => true }
        format.html {
                      flash[:notice] = t(:'flash.tickets.unwatch.unsubscribe_success') 
                      redirect_to helpdesk_ticket_path(@ticket)
                    }
    end
  end

  def unwatch_multiple
    if Helpdesk::Subscription.destroy_all(:ticket_id => current_account.tickets.find( :all, 
                                              :conditions => { :display_id => params[:ids] }).map(&:id),
                                         :user_id => current_user.id,
                                         :account_id => current_account.id)
      flash[:notice] = render_to_string(
          :inline => t("flash.tickets.unwatch.success", :tickets => get_updated_ticket_count ))
    else
      flash[:notice] = t(:'flash.tickets.unwatch.failure')
    end
    redirect_to helpdesk_tickets_path
  end

  def unsubscribe
    unwatch
  end

  protected
    def get_updated_ticket_count
      pluralize(params[:ids].length, t('ticket_was'), t('tickets_were'))
    end

    def load_parent_ticket
      @parent = Helpdesk::Ticket.find_by_param(params[:ticket_id], current_account) 
      raise ActiveRecord::RecordNotFound unless @parent
    end
end
