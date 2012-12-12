class Billing::BillingsController < ApplicationController

	before_filter :login_from_basic_auth

	skip_before_filter :set_time_zone, :set_locale, :check_account_state, :ensure_proper_protocol,
											 :check_day_pass_usage, :redirect_to_mobile_url

	before_filter :ensure_right_parameters, :retrieve_account

	
	EVENTS = [ "subscription_renewed", "payment_succeeded" ]

	INVOICE_TYPES = { :recurring => "0", :non_recurring => "1" }

	META_INFO = { :plan => :subscription_plan_id, :renewal_period => :renewal_period, :agents => :agent_limit,
								:free_agents => :free_agents, :discount => :subscription_discount_id}


	def trigger
  	send(params[:event_type], params[:content]) if EVENTS.include?(params[:event_type])

  	respond_to do |format|
  	 format.xml  { head 200 }
  	end
	end

	
	private

		def login_from_basic_auth
			authenticate_or_request_with_http_basic do |username, password|
				password_hash = Digest::MD5.hexdigest(password)
				username == 'freshdesk' && password_hash == "19dd4cc2e6690719263b5b749d197b26"  #password = "FDCB$6M"
			end
    	end

		def ensure_right_parameters
			if ((!request.ssl?) or (!request.post?) or 
					(params[:event_type].blank?) or (params[:content].blank?))
				return render :xml => ArgumentError, :status => 500
			end
		end

		def retrieve_account
			@account = Account.find(params[:content].subscription_id)
			return render :xml => ActiveRecord::RecordNotFound, :status => 404 unless @account
		end

		
		def subscription_renewed(content)
			@account.subscription.update_attributes(:next_renewal_at => next_billing(content.subscription) )
		end

		def next_billing(subscription)
			Time.at(subscription.current_term_end).to_datetime.to_s(:db)
		end

		
		def payment_succeeded(content)
			SubscriptionPayment.create(payment_info(content))
		end

		def payment_info(content)
			{
				:account => @account,
				:amount => content.transaction.amount,
				:transaction_id => content.transaction.id_at_gateway, 
				:affiliate => null,
				:misc => recurring_invoice?,
				:meta_info => build_meta_info
			}
		end

		def recurring_invoice?
			(content.invoice.recurring)? INVOICE_TYPES[:recurring] : INVOICE_TYPES[:non_recurring]
		end

		def build_meta_info(content)
			# {
			# 	:plan => @account.subscription.subscription_plan_id,
			# 	:renewal_period => @account.subscription.renewal_period,
			# 	:agents => @account.subscription.agent_limit,
			# 	:free_agents => @account.subscription.free_agents,
			# 	:discount => @account.subscription.subscription_discount_id,
			#   :description => content.invoice.line_items[0].description
			# }
			meta_info = META_INFO.inject({}) { |h, (k, v)| h[k] = @account.subscription.send(v); h }
			meta_info.merge({ :description => content.invoice.line_items[0].description })
		end

end