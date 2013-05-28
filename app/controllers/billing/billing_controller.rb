class Billing::BillingController < ApplicationController

  before_filter :login_from_basic_auth, :ssl_check

  skip_before_filter :set_time_zone, :set_locale, :check_account_state, :ensure_proper_protocol,
                      :check_day_pass_usage, :redirect_to_mobile_url

  before_filter :ensure_right_parameters, :retrieve_account, :if => :event_monitored?

  before_filter :load_subscription_info, :if => :subscription_info_available?
 
  
  EVENTS = [ "subscription_changed", "subscription_activated", "subscription_renewed", 
              "subscription_cancelled", "subscription_reactivated", "card_added", 
              "card_updated", "payment_succeeded", "payment_refunded" ]          

  INVOICE_TYPES = { :recurring => "0", :non_recurring => "1" }

  META_INFO = { :plan => :subscription_plan_id, :renewal_period => :renewal_period, 
                :agents => :agent_limit, :free_agents => :free_agents }

  ADDRESS_INFO = { :first_name => :first_name, :last_name => :last_name, :address1 => :billing_addr1,
                    :address2 => :billing_addr2, :city => :billing_city, :state => :billing_state,
                    :country => :billing_country, :zip => :billing_zip  }

  IN_TRIAL = "in_trial"
  CANCELLED = "cancelled"
  NO_CARD = "no_card"
  OFFLINE = "off"

  TRIAL = "trial"
  FREE = "free"
  ACTIVE = "active"  
  SUSPENDED = "suspended"              

  
  def trigger
    send(params[:event_type], params[:content]) if event_monitored?

    respond_to do |format|
      format.xml { head 200 }
      format.json  { head 200 }
    end
  end


  private

    #Authentication
    def login_from_basic_auth
      authenticate_or_request_with_http_basic do |username, password|
        password_hash = Digest::MD5.hexdigest(password)
        username == 'freshdesk' && password_hash == "5c8231431eca2c61377371de706a52cc" 
      end
    end

    def ssl_check
      render :json => ArgumentError, :status => 500 if (Rails.env.production? and !request.ssl?)
    end

    def event_monitored?
      EVENTS.include?(params[:event_type])
    end

    def subscription_info_available? 
      params[:content][:subscription]
    end 

    def ensure_right_parameters
      if ((params[:event_type].blank?) or (params[:content].blank?) or params[:content][:customer].blank?)
        return render :json => ArgumentError, :status => 500
      end
    end

    def retrieve_account
      @account = Account.find(params[:content][:customer][:id])
      return render :json => ActiveRecord::RecordNotFound, :status => 404 unless @account
    end

    #Subscription info
    def load_subscription_info
      @subscription_data = subscription_info(params[:content][:subscription], params[:content][:customer])
    end

    def subscription_info(subscription, customer)
      {
        :subscription_plan => subscription_plan(subscription[:plan_id]),
        :day_pass_amount => subscription_plan(subscription[:plan_id]).day_pass_amount,
        :renewal_period => billing_period(subscription[:plan_id]),
        :agent_limit => subscription[:plan_quantity],
        :free_agents => subscription_plan(subscription[:plan_id]).free_agents,
        :state => subscription_state(subscription, customer),
        :next_renewal_at => next_billing(subscription)
      }
    end

    def subscription_plan(plan_code)
      SubscriptionPlan.find_by_name(helpkit_subscription_plan(plan_code))
    end

    def helpkit_subscription_plan(plan_code)
      SubscriptionPlan::SUBSCRIPTION_PLANS[Billing::Subscription.helpkit_plan[plan_code].to_sym]
    end

    def billing_period(plan_code)
      Billing::Subscription.billing_cycle[plan_code]
    end

    def subscription_state(subscription, customer)
      status =  subscription[:status]
      
      case
        when (customer[:auto_collection].eql?(OFFLINE) and status.eql?(ACTIVE))
          ACTIVE
        when status.eql?(IN_TRIAL)
          TRIAL
        when (status.eql?(ACTIVE) and customer[:card_status].eql?(NO_CARD))
          FREE
        when status.eql?(ACTIVE)
          ACTIVE
        when (status.eql?(CANCELLED))
          SUSPENDED
      end   
    end

    def next_billing(subscription)
      if (renewal_date = subscription[:current_term_end])
        Time.at(renewal_date).to_datetime.utc
      else
        Time.at(subscription[:trial_end]).to_datetime.utc
      end
    end

    #Events
    def subscription_changed(content)
      # @account.subscription.update_attributes(@subscription_data)
    end

    def subscription_activated(content)
      @account.subscription.update_attributes(@subscription_data)
    end

    def subscription_renewed(content)
      @account.subscription.update_attributes(@subscription_data)
    end

    def subscription_cancelled(content)
      @account.subscription.update_attribute(:state, SUSPENDED)
    end

    def subscription_reactivated(content)
      @account.subscription.update_attributes(@subscription_data)
    end

    def card_added(content)
      @account.subscription.update_attributes(card_info(content[:card]))
      update_billing_address(content[:card], @account.subscription)
    end
    alias :card_updated :card_added

    def payment_succeeded(content)
      @account.subscription.subscription_payments.create(payment_info(content))
    end

    def payment_refunded(content)
      @account.subscription.subscription_payments.create(
              :account => @account, :amount => -(content[:transaction][:amount]/100))
    end


    #Card and Payment info
    def card_info(card)
      {
        :card_number => card[:masked_number],
        :card_expiration => "%02d-%d" % [card[:expiry_month], card[:expiry_year]]
      }
    end

    def payment_info(content)
      {
        :account => @account,
        :amount => content[:transaction][:amount]/100,
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

    #Billing Address
    def update_billing_address(card, subscription)
      billing_address = subscription.billing_address

      return billing_address.update_attributes(address(card)) if billing_address

      billing_address = subscription.build_billing_address(address(card))
      billing_address.account = @account
      billing_address.save
    end

    def address(card)
      ADDRESS_INFO.inject({}) { |h, (k, v)| h[k] = card[v]; h }
    end

end