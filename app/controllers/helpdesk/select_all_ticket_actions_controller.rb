class Helpdesk::SelectAllTicketActionsController < ApplicationController
  include Redis::RedisKeys
  include Redis::OthersRedis
  include SelectAllRedisMethods
  include Helpdesk::TicketActions
  helper Helpdesk::SelectAllHelper

  before_filter :set_default_filter , :only => [:close_ticket, :spam_ticket, :delete_ticket, :bulk_update]

  def select_all_message_content
  end

  def enqueue_select_all
    select_all_redis_value = bulk_action_redis_value
    if select_all_redis_value.present?
      if current_user.id.to_s == select_all_redis_value["user_id"]
        flash[:error] = render_to_string(:inline => t("ticket.admin_select_all.select_all_already_running_you"))
      else
        flash[:error] = render_to_string(:inline => t("ticket.admin_select_all.select_all_already_running", :user_name => select_all_redis_value["user_name"]))
      end
    elsif params[:action] != "update_multiple" || params[:helpdesk_ticket].present?
      flash[:notice] = render_to_string(:inline => t("ticket.admin_select_all.select_all_enqueued"))
      user_id = current_user.id
      sidekiq_params = cleanup_params
      set_bulk_action_redis_key(sidekiq_params)
      Tickets::SelectAll::BatcherWorker.perform_async(sidekiq_params, current_account.id, user_id)
    else
      flash[:error] = render_to_string(:inline => t("ticket.admin_select_all.no_fields_selected"))
    end
    respond_to do |format|
      format.html{ redirect_to :back }
    end
  end

  alias_method :close_multiple, :enqueue_select_all
  alias_method :spam, :enqueue_select_all
  alias_method :delete, :enqueue_select_all
  alias_method :update_multiple, :enqueue_select_all

  private
    def cleanup_params
      clean_params = params.except(:_method, :authenticity_token, :controller, :utf8)
      clean_params[:enqueued_time] = Time.now.utc
      clean_params
    end

end
