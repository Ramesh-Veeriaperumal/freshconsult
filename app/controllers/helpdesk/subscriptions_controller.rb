class Helpdesk::SubscriptionsController < ApplicationController

  include ActionView::Helpers::TextHelper

  before_filter { |c| c.requires_permission :manage_tickets }
  before_filter :load_parent_ticket , :except => :unwatch_multiple

  def index
    @ticket = @parent
    render :partial => "helpdesk/subscriptions/ticket_watchers"
  end

  def create_watchers
    @ticket = @parent
    agent_ids = current_account.agents.find(:all, 
                                          :conditions => {:user_id => params[:ids]}).map(&:user_id)
    if agent_ids.present?
      @subscriptions = @ticket.subscriptions.create(agent_ids.collect { |u_id| {:user_id => u_id} })

      @subscriptions.each do |subscription|
        if current_user.id != subscription.user_id
          Helpdesk::WatcherNotifier.send_later(:deliver_notify_new_watcher, 
                                               @ticket, 
                                               subscription, 
                                               "#{current_user.name}")
        end
      end
    end

    render :partial => "helpdesk/subscriptions/update_watcher_script"
  end

  def unwatch
    @ticket = @parent
    subscription = @ticket.subscriptions.find_by_user_id(current_user.id)
    subscription.destroy if subscription
    respond_to do |format|
        format.js { render :partial => "update_watcher_script" }
        format.html {
                      flash[:notice] = t(:'flash.tickets.unwatch.unsubscribe_success') 
                      redirect_to helpdesk_ticket_path(@ticket)
                    }
    end
  end

  def unwatch_multiple
    if Helpdesk::Subscription.destroy_all(:ticket_id => params[:ids],
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
