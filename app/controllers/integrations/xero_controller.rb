 class Integrations::XeroController < ApplicationController

 	skip_before_filter :set_current_account, :check_privilege, :check_account_state, :set_time_zone,
                    :check_day_pass_usage, :set_locale, :only => [:install]

 	before_filter :get_xero_client
 	before_filter :authorize_client, :except => [:authorize, :install, :authdone]
	 	
	def authorize
		request_token = @xero_client.request_token(:oauth_callback => "#{AppConfig['integrations_url'][Rails.env]}/integrations/xero/install?redirect_url=#{request.protocol+request.host_with_port}")		
		session[:xero_request_token]  = request_token.token
		session[:xero_request_secret] = request_token.secret	
		redirect_to request_token.authorize_url
		rescue Exception => e 
			flash[:notice] = t(:'flash.application.install.error') 
			redirect_to :controller=> 'applications', :action => 'index'
	end

	def install	
		redirect_url ="#{params[:redirect_url]}/integrations/xero/authdone?oauth_verifier=#{params[:oauth_verifier]}"
		redirect_to redirect_url
	end

	def authdone
		@xero_client.authorize_from_request(
				session[:xero_request_token],
				session[:xero_request_secret], 
				:oauth_verifier => params[:oauth_verifier] )
		config_params = { 
	      'refresh_token' => "#{@xero_client.session_handle}",
	      'oauth_token' => "#{@xero_client.access_token.token}",
	      'oauth_secret' => "#{@xero_client.access_token.secret}",
	      'expires_at' => "#{@xero_client.client.instance_variable_get(:@expires_at)}"
		}
		session.delete(:xero_request_token)
		session.delete(:xero_request_secret)
		installed_application = Integrations::Application.install_or_update(Integrations::Constants::APP_NAMES[:xero], current_account.id, config_params)
		flash[:notice] = t(:'flash.application.install.success') if installed_application
		redirect_to :controller=> 'applications', :action => 'index'
	end

	def fetch
		installed_app = current_account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:xero]).first
		integrated_resource = Integrations::IntegratedResource.find_by_installed_application_id_and_local_integratable_id(installed_app.id, params["ticket_id"])
		company_contact, contact, available_name = check_contact_exist
		inv_items = {}
		if contact.response_item.present?
			contact_id =  contact.invoice.contact_id
			query = %Q[Contact.ContactID=Guid("#{contact_id}")]
			invoices = @xero_client.get_invoices(:where => query, :modified_since => 1.month.ago, :direction => :asc)

			Array.wrap(invoices.response_item).compact.each_with_index do |inv, i|
				inv_items[i] = { 
					"invoice_number" => inv.invoice_number,
					 "invoice_id" => inv.invoice_id, 
					 "invoice_status" => inv.invoice_status,
					 "currency_code" => inv.currency_code, 
					 "date" => inv.date, 
					 "due_date" => inv.due_date
				}
			end		

		end

		render :json => {:inv_items => inv_items, :remote_id => {"remote_integratable_id" => integrated_resource.try(:remote_integratable_id).to_s, "integrated_resource_id" => integrated_resource.try(:id).to_s } }
	end

	def get_invoice		
		invoice = @xero_client.get_invoice(params["invoiceID"])
		render :xml => invoice.response_xml
	end

	def fetch_create_contacts
		company_contact, contact, available_name = check_contact_exist
		if company_contact
			if contact.response_item.blank?
				contact =@xero_client.build_contact
				contact.name = available_name
				contact.email = params["reqEmail"]
				contact  = contact.save
				render :text => contact.invoice.contact_id
			else
				render :text => contact.invoice.contact_id
			end
		else
			render :text => contact.invoice.contact_id
		end		
	end

	def check_contact_exist
		available_name = (params["reqCompanyName"].blank?) ? params["reqName"] : params["reqCompanyName"]
		company_name = %Q[Name="#{available_name}"]
		contact = @xero_client.get_contacts(:where => company_name)
		if company_contact = contact.response_item.blank?
			email_query = %Q[EmailAddress ="#{params["reqEmail"]}"]
			contact = @xero_client.get_contacts(:where => email_query)	
		end
		[company_contact, contact, available_name  ]
	end

	def render_accounts
		account_list = @xero_client.get_accounts_list
		if params["ID"].eql? "xero_dialog_create"	
			equity = account_list.find_all_by_type('EQUITY')
			revenue = account_list.find_all_by_type('REVENUE')
			direct_costs = account_list.find_all_by_type('DIRECTCOSTS')
			fixed  = account_list.find_all_by_type('FIXED')
			termliab = account_list.find_all_by_type('TERMLIAB')
			currliab = account_list.find_all_by_type('CURRLIAB')
			expense = account_list.find_all_by_type('EXPENSE')			
			currliab_new = currliab.reject {|a| a.code.in? INVALID_XERO_CURRLIAB}
			expense_new = expense.reject {|a| a.code.in? INVALID_XERO_EXPENSE}
			accounts =  revenue + equity + currliab_new + termliab  + Array.wrap(account_list.find_by_code(INVALID_XERO_CODE)) + fixed + direct_costs  +  expense_new 
		else
			accounts  = Array.wrap(account_list.find_by_code(params["code"]))		
		end
		render :json => accounts
	end

	def render_currency	
		currency = @xero_client.get_currencies
		render :xml =>currency.response_xml 
	end

	def create_invoices
			line_item = []
			line_items =JSON.parse(params["line_items"])
			line_items.each do |key,value|
			  line_item << XeroGateway::LineItem.new( :description => value["description"], :quantity => value["time_spent"].to_f, :unit_amount => value["unit_amount"].to_f, :account_code => value["account_code"])
			end

			invoice = XeroGateway::Invoice.new({:line_amount_types => "Exclusive", :date => Date.parse(params["current_date"]), :due_date => Date.parse(params["due_date"]), :invoice_type => "ACCREC", :line_items => line_item, :currency_code => params["currency_id"]})

			if params["invoice_id"].present?
			  invoice.invoice_id = params["invoice_id"]
			else
			  invoice.contact.contact_id = params["contact_id"]
			end

			res =@xero_client.create_invoice(invoice)
			render :json => { :invoice_details => { "invoice_number" => res.response_item.invoice_number ,"invoice_id" => res.response_item.invoice_id } }
		rescue Exception => e
		  render :text => "A validation exception has occured"
	end

	def delete_invoice
		 invoice_del = @xero_client.get_invoice(params["invoice_id"])
		 unless invoice_del.contact.invoice_status.eql? "DELETED"	
			 invoice_del.contact.invoice_status = "DELETED"		
			 @xero_client.update_invoice(invoice_del.invoice)
			 render :text => invoice_del.response_item.invoice_number
		 else
		 	 render :text => invoice_del.response_item.invoice_number
		 end
		rescue Exception => e
		  render :text => "failure"
	end

 	private

	def get_xero_client
		@xero_client = XeroGateway::PartnerApp.new(XERO_CONSUMER_KEY, XERO_CONSUMER_SECRET, {:ssl_client_cert  => XERO_PATH_TO_SSL_CLIENT_CERT, :ssl_client_key => XERO_PATH_TO_SSL_CLIENT_KEY,
			:private_key_file => XERO_PATH_TO_PRIVATE_KEY})
	end

	def authorize_client
		@installed_app = current_account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:xero]).first
		installed =@installed_app.configs[:inputs]
		expires_at  =installed["expires_at"] 
		token_valid_till = (Time.parse(expires_at) - Time.now)/60
		if token_valid_till < 1
			@xero_client.renew_access_token(installed["oauth_token"], installed["oauth_secret"], installed["refresh_token"]	)	
			@xero_client.authorize_from_access( @xero_client.access_token.token, @xero_client.access_token.token)	
			config_params = { 
			      'refresh_token' => "#{@xero_client.session_handle}",
			      'oauth_token' => "#{@xero_client.access_token.token}",
			      'oauth_secret' => "#{@xero_client.access_token.secret}",
			      'expires_at' => "#{@xero_client.client.instance_variable_get(:@expires_at)}"
				}	
			installed_application = Integrations::Application.install_or_update(Integrations::Constants::APP_NAMES[:xero], current_account.id, config_params)
		else
			@xero_client.authorize_from_access( installed["oauth_token"], installed["oauth_secret"])
		end
	end

 end

