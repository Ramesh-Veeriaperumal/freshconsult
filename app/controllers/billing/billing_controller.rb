class Billing::BillingController < ApplicationController

  #before_filter :login_from_basic_auth
  before_filter :ssl_check

  skip_before_filter :set_time_zone, :set_locale, :check_account_state, :ensure_proper_protocol,
                      :check_day_pass_usage, :redirect_to_mobile_url

  before_filter :ensure_right_parameters, :retrieve_account, :unless => :ping_event?

  PING_EVENT = "ping"

  EVENTS = [ "subscription_renewed", "payment_succeeded" ]

  INVOICE_TYPES = { :recurring => "0", :non_recurring => "1" }

  META_INFO = { :plan => :subscription_plan_id, :renewal_period => :renewal_period, :agents => :agent_limit,
                :free_agents => :free_agents, :discount => :subscription_discount_id}


  def trigger
    send(params[:event_type], params[:content]) if EVENTS.include?(params[:event_type])

    respond_to do |format|
      format.xml { head 200 }
      format.json  { head 200 }
    end
  end


  private

    def login_from_basic_auth
      authenticate_or_request_with_http_basic do |username, password|
        password_hash = Digest::MD5.hexdigest(password)
        username == 'freshdesk' && password_hash == "5c8231431eca2c61377371de706a52cc" 
      end
    end

    def ssl_check
      render :json => ArgumentError, :status => 500 if (Rails.env.production? and !request.ssl?)
    end

    def ping_event?
      params[:event_type].eql?(PING_EVENT)
    end

    def ensure_right_parameters
      if ((params[:event_type].blank?) or (params[:content].blank?))
        return render :json => ArgumentError, :status => 500
      end
    end

    def retrieve_account
      @account = Account.find(params[:content][:subscription][:id])
      return render :json => ActiveRecord::RecordNotFound, :status => 404 unless @account
    end


    def subscription_renewed(content)
      #@account.subscription.update_attributes(:next_renewal_at => next_billing(content[:subscription]))
      SubscriptionEvent.create(:account_id => content[:subscription][:id],
                                :code => EVENTS[0],
                                :info => content)
    end

    def next_billing(subscription)
      Time.at(subscription[:current_term_end]).to_datetime.to_s(:db)
    end


    def payment_succeeded(content)
      #@account.subscription.subscription_payments.create(payment_info(content))
      SubscriptionEvent.create(:account_id => content[:subscription][:id], 
                                :code => EVENTS[1],
                                :info => content)
    end

    def payment_info(content)
      {
        :account => @account,
        :amount => content[:transaction][:amount],
        :transaction_id => content[:transaction][:id_at_gateway], 
        :misc => recurring_invoice?(content[:invoice]),
        :meta_info => build_meta_info(content[:invoice])
      }
    end

    def recurring_invoice?(invoice)
      (invoice[:recurring])? INVOICE_TYPES[:recurring] : INVOICE_TYPES[:non_recurring]
    end

    def build_meta_info(invoice)
      meta_info = META_INFO.inject({}) { |h, (k, v)| h[k] = @account.subscription.send(v); h }
      meta_info.merge({ :description => invoice[:line_items][0][:description] })
    end

end