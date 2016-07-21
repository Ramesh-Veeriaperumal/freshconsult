class CRM::FreshsalesUtility

  NEGATIVE_LEAD_STAGES    = ['Unqualified']
  
  PRODUCT_NAME            = AppConfig['app_name']
  
  WON_DEAL_STAGE          = 'Closed Won'
  
  LOST_DEAL_STAGE         = 'Closed Lost'
  
  PAYMENT_STATUS          = { online: "Online", offline: "Offline" }
  
  LOOKUP_URL              = "/lookup.json?f=%{field}&entities=%{entities}&q=%{query}&include=%{includes}&per_page=100"
  
  SELECTOR_URL            = "/selector/%{entity_type}"
  
  CUSTOMER_STATUS         = { trial: 'Trial', suspended: 'Trial Expired', free: 'Free', 
                              paid: 'Customer', deleted: 'Deleted', active: 'Active', 
                              no_payment_suspended: 'Suspended', trial_extended: 'Trial Extended',
                              deleted: "Deleted" }
  
  DEAL_TYPES              = { new_business: 'New Business', upgrade: 'Existing Business-Upgrade', 
                              downgrade: 'Existing Business-Downgrade', 
                              renewal: 'Existing Business-Renewal' }
  
  OFFLINE                 = 'off'
  
  ZERO                    = 0

  DEFAULT_ACCOUNT_MANAGER = { display_name:   "Bobby",
                              email:          "eval@freshdesk.com" }

  def initialize(data)
    @account = data[:account]
    @subscription = data[:subscription]
    @cmrr = data[:cmrr]
    
    @deal_product_id = get_entity_id('deal_products', :name, PRODUCT_NAME)
  end

  def push_signup_data(data)
    result = search({ entities: 'lead,contact', field: 'email', query: @account.admin_email, 
                      includes: 'owner,lead_stage' })
    lead = recently_updated(result[:leads])
    contact = result[:contacts].first

    if contact
      status, response = create_lead_with_same_owner(contact[:owner_id], contact[:updated_at])
    elsif lead
      status, response = create_or_update_lead(lead, result[:lead_stages])
    else
      sales_account = search_accounts_by_name(@account.name, 'owner')[:sales_accounts].first
      if sales_account
        status, response = create_lead_with_same_owner(sales_account[:owner_id], sales_account[:updated_at])
      else
        company_leads = search_leads_by_company_name(@account.name, 'owner')[:leads]
        company_lead  = recent_lead_by_account_and_product(company_leads, @account.id, @deal_product_id)
        status, response = company_lead ? create_lead_with_same_owner(company_lead[:owner_id], company_lead[:updated_at]) : 
                                          fs_create('lead', new_lead_params)
      end
    end

    if status.eql?(200) && data[:fs_cookie].present?
      visitor_info = { cookie: data[:fs_cookie], product_id: @deal_product_id }
      config = { rest_url: "/leads/#{response[:lead][:id]}/associate_to_visitor", method: 'post', body: visitor_info }
      request_freshsales(config)
    end
  end

  def update_admin_info
    result = search_deals_by_account_and_product(@account.id, @deal_product_id, 'contacts,sales_account,deal_product')

    if result[:deals].any?
      contact = result[:contacts].find{ |contact| contact[:email] == @account.admin_email }
      if contact
        fs_update('contact', contact[:id], admin_basic_info)
      else
        deal_account = result[:sales_accounts].find{ |acc| acc[:id] == result[:deals].first[:sales_account_id] }
        contact_info = admin_basic_info.merge({ sales_account_id: deal_account[:id] })
        status, response = fs_create('contact', contact_info)
        associate_deals_to_contact(result[:deals], response[:contact][:id]) if status.eql?(200)
      end
    else
      leads = search_leads_by_account_and_product(@account.id, @deal_product_id, 'owner')[:leads]
      if leads.any?
        recent_lead = recently_updated(leads)
        admin_leads = leads.select{ |lead| lead[:email] == @account.admin_email }
        admin_leads.any? ? fs_update('lead', recently_updated(admin_leads)[:id], admin_basic_info) : 
                           create_lead_with_same_owner(recent_lead[:owner_id], recent_lead[:updated_at])
      else
        fs_create('lead', new_lead_params)
      end
    end
  end

  def push_subscription_changes(deal_type, amount, payments_count)
    Rails.logger.debug "In FreshsalesUtility::push_subscription_changes :: deal_type :: #{deal_type} :: amount :: #{amount}"

    result = search_deals_by_account_and_product(@account.id, @deal_product_id, 'sales_account,deal_stage,deal_type,deal_product')
    customer_status = get_customer_status(@subscription[:state].to_sym, payments_count)

    if result[:deals].any?
      open_deal = (deal_type == :downgrade) ? nil : recent_open_deal(result[:deals], result[:deal_stages])
      if open_deal
        mark_deal_as_closed_won(open_deal, { deal_type: deal_type, amount: amount })
      else
        deal_type = ((deal_type == :new_business) && get_new_business_deal(result[:deals]).present?) ? :upgrade : deal_type
        deal_account_id = result[:sales_accounts].find{ |acc| acc[:id] == result[:deals].first[:sales_account_id] }[:id]
        deal_params = { deal_type: deal_type, amount: amount, customer_status: customer_status, 
                        sales_account_id: deal_account_id }.merge(contact_and_owner(deal_account_id))
        create_deal_and_close(deal_params)
      end
      mark_deals_status(result[:deals], customer_status)
    else
      leads = search_leads_by_account_and_product(@account.id, @deal_product_id)[:leads]

      admin_leads = leads.select{|lead| lead[:email] == @account.admin_email }
      admin_lead  = recently_updated(admin_leads)
      lead_params = { deal_type: deal_type, amount: amount, customer_status: customer_status }
      admin_lead  ? convert_lead_and_close_deal(admin_lead, lead_params) : create_lead_and_convert_and_close_deal(lead_params)

      other_leads_of_account = admin_lead.nil? ? leads : (leads - [admin_lead])
      other_leads_of_account.each{|lead| convert_lead(lead) }
    end    
  end

  def account_trial_expiry
    Rails.logger.debug "In FreshsalesUtility :: account_trial_expiry"
    update_deal_or_lead({ custom_field: { cf_customer_status: CUSTOMER_STATUS[@subscription[:state].to_sym] } })
  end

  def account_cancellation
    Rails.logger.debug "In FreshsalesUtility :: account_cancellation"
    update_deal_or_lead({ custom_field: { cf_customer_status: CUSTOMER_STATUS[:deleted] } })
  end

  def account_trial_extension
    Rails.logger.debug "In FreshsalesUtility :: account_trial_extension"
    data = { custom_field: { cf_customer_status: CUSTOMER_STATUS[:trial_extended], 
                             cf_trial_expiry_date: @subscription[:next_renewal_at] } }
    update_deal_or_lead(data)
  end

  def account_manager
    result = search_leads_by_account_and_product(@account.id, @deal_product_id, 'owner')
    recent_lead = recently_updated(result[:leads])
    account_manger_info = recent_lead ? result[:users].find{ |user| user[:id] == recent_lead[:owner_id] } : DEFAULT_ACCOUNT_MANAGER
  end

  private

    def admin_basic_info
      { first_name: @account.admin_first_name, last_name: (@account.admin_last_name || @account.admin_first_name),
        work_number: @account.admin_phone, email: @account.admin_email }
    end

    def account_basic_info
      { name: @account.name }
    end

    def account_metrics
      metrics = @account.conversion_metric
      {
        lead_attrs: {
          city: metrics.try(:city_name), state: metrics.try(:region_name),
          country: metrics.try(:country), zipcode: metrics.try(:zip_code)
        },
        custom_attrs: {
          cf_first_referrer: metrics.try(:first_referrer), 
          cf_signup_referrer: metrics.try(:landing_url)
        }
      }
    end

    def new_lead_subscription_params
      {
        custom_attrs: {
          cf_agent_count: @subscription[:agent_limit], 
          cf_customer_status: CUSTOMER_STATUS[@subscription[:state].to_sym],
          cf_signup_date: @subscription[:created_at].strftime("%Y-%m-%d")
        },
        deal_attrs: {
          name: deal_name(@account.full_domain, :new_business),
          amount: @cmrr.round(2),
          deal_product_id: @deal_product_id
        }
      }
    end

    def new_lead_params
      lead_attrs = admin_basic_info.merge({
        custom_field: {
          cf_account_id:  @account.id, cf_domain_name: @account.full_domain,
        }
      })
      lead_attrs[:company] = account_basic_info

      acc_metrics = account_metrics
      subscription_attrs = new_lead_subscription_params

      lead_attrs[:deal] = subscription_attrs[:deal_attrs]
      lead_attrs.merge!(acc_metrics[:lead_attrs])
      lead_attrs[:custom_field].merge!(acc_metrics[:custom_attrs].merge(subscription_attrs[:custom_attrs]))

      lead_attrs
    end

    def won_deal_params
      {
        deal_stage_id: get_entity_id('deal_stages', :forecast_type, WON_DEAL_STAGE),
        deal_payment_status_id: payment_status_id,
        custom_field: {
          cf_number_of_agents: @subscription[:agent_limit],
          cf_plan: SubscriptionPlan.find_by_id(@subscription[:subscription_plan_id]).try(:name),
          cf_customer_status: CUSTOMER_STATUS[@subscription[:state].to_sym],
          cf_domain_name: @account.full_domain,
          cf_signup_date: @subscription[:created_at].strftime("%Y-%m-%d")
        }
      }
    end

    def contact_and_owner(sales_account_id)
      params = {}
      status, account_result = fs_get('sales_account', sales_account_id, 'owner,contacts')
      if status.eql?(200)
        account_contact = account_result[:contacts].find{ |cont| cont[:email] == @account.admin_email }
        owner_id = account_contact.try(:[], :owner_id) || account_result[:sales_account][:owner_id]
        params.merge!({ contact_id: account_contact.try(:[], :id), owner_id: owner_id })
      end
      params
    end

    def get_entity_id(entity_type, find_by, query_str)
      entities = get_all(entity_type)
      entities.find{ |entity| entity[find_by.to_sym] == query_str }.try(:[], :id)
    end

    def deal_name(domain, type)
      "#{domain} - #{DEAL_TYPES[type.to_sym]}" 
    end

    def paid_customer?(payments_count)
      payments_count > ZERO
    end
    
    def get_customer_status(state, payments_count)
      (state == :suspended && paid_customer?(payments_count)) ? 
                                CUSTOMER_STATUS[:no_payment_suspended] : CUSTOMER_STATUS[state]
    end

    def payment_status_id
      status = @subscription[:card_number].blank? ? :offline : :online
      get_entity_id('deal_payment_statuses', :name, PAYMENT_STATUS[status])
    end

    def get_new_business_deal(deals)
      type_id = get_entity_id('deal_types', :name, "New Business")
      deals.find{ |deal| deal[:deal_type_id] == type_id }
    end

    def extended_trial?(deal)
      deal[:custom_field][:cf_customer_status].eql?(CUSTOMER_STATUS[:trial_extended])
    end

    def update_deal_or_lead(data)
      result    = search_deals_by_account_and_product(@account.id, @deal_product_id, 'deal_product')

      if result[:deals].any?
        deal_ids = result[:deals].map{ |i| i[:id] }
        fs_bulk_update('deal', deal_ids, data) if deal_ids.any?
      else
        leads = search_leads_by_account_and_product(@account.id, @deal_product_id)[:leads]
        lead_ids = leads.map{ |i| i[:id] }
        fs_bulk_update('lead', lead_ids, data) if lead_ids.any?
      end
    end

    def create_or_update_lead(lead, stages)
      if lead_in_negative_stage?(lead, stages)
        fs_create('lead', new_lead_params)
      else
        if lead[:deal].try(:[], :deal_product_id).blank?
          deal_info = { 
            deal: { deal_product_id: @deal_product_id }, 
            custom_field: { cf_account_id: @account.id, cf_domain_name: @account.full_domain }
          }
          fs_update('lead', lead[:id], deal_info)
        else
          create_lead_with_same_owner(lead[:owner_id], lead[:updated_at])
        end
      end
    end

    def lead_in_negative_stage?(lead, stages)
      stage_name = stages.find{ |stage| stage[:id] == lead[:lead_stage_id] }.try(:[], :name)
      NEGATIVE_LEAD_STAGES.include?(stage_name)
    end

    def create_lead_with_same_owner(owner_id, updated_at) 
      lead_info = new_lead_params     
      lead_info.merge!({ owner_id: owner_id }) if updated_in_last_90_days?(updated_at)

      fs_create('lead', lead_info)
    end

    def updated_in_last_90_days?(updated_at)
      ((DateTime.now.utc.to_f - DateTime.parse(updated_at).to_f).to_i / 1.day) < 90
    end

    def associate_deals_to_contact(deals, contact_id)
      deal_ids = deals.map!{ |deal| deal[:id] }
      deal_ids.each do |deal_id|
        deal_info = { contacts_added_list: [contact_id] }
        fs_update('deal', deal_id, deal_info)
      end
    end

    def create_deal_and_close(options)
      attributes   = won_deal_params
      deal_type_id = get_entity_id('deal_types', :name, DEAL_TYPES[options[:deal_type]])

      attributes.merge!({
        name: deal_name(@account.full_domain, options[:deal_type]),
        amount: options[:amount],
        deal_product_id: @deal_product_id, 
        sales_account_id: options[:sales_account_id],
        owner_id: options[:owner_id],
        deal_type_id: deal_type_id,
        custom_field: attributes[:custom_field].merge({ cf_account_id: @account.id, cf_customer_status: options[:customer_status] })
      })

      attributes.merge!({ contacts_added_list: [options[:contact_id]] }) if options[:contact_id]

      fs_create('deal', attributes)
    end
 
    def create_lead_and_convert_and_close_deal(options)
      lead_info        = new_lead_params

      config = { rest_url: "/sessions", method: 'get' }
      user_status, user_response = request_freshsales(config)
      lead_info[:owner_id] = user_response[:user][:id] if user_status.eql?(200)

      status, response = fs_create('lead', lead_info)
      convert_lead_and_close_deal(response[:lead], { deal_type: options[:deal_type],
                                                     amount: options[:amount],
                                                     customer_status: options[:customer_status] }) if status.eql?(200)
    end

    def convert_lead_and_close_deal(lead, options)
      convert_status, convert_response = convert_lead(lead, options)
      return unless convert_status.eql?(200)

      status, response = fs_get('contact', convert_response[:contact][:id], 'deals')
      if status.eql?(200)
        deals = deals_by_account_and_product(response[:deals], @account.id, @deal_product_id)
        open_deal = recent_open_deal(deals, response[:deal_stages])
        mark_deal_as_closed_won(open_deal, { deal_type: options[:deal_type], customer_status: options[:customer_status] })
      end
    end

    def convert_lead(lead, options={})
      data = { last_name: lead[:last_name], email: lead[:email], company: { name: lead[:company][:name] } }

      if options.present? && options[:deal_type].present? && options[:amount].present?
        data.merge!({deal: { name: deal_name(@account.full_domain, options[:deal_type]), amount: options[:amount] }})
      end

      config = { rest_url: "/leads/#{lead[:id]}/convert", method: 'post', body: { 'lead' => data } }
      request_freshsales(config)
    end

    def mark_deal_as_closed_won(open_deal, options)
      attributes = won_deal_params

      if options[:deal_type].present?
        deal_type_id = get_entity_id('deal_types', :name, DEAL_TYPES[options[:deal_type]])
        attributes.merge!({ deal_type_id: deal_type_id })
      end
      attributes[:custom_field].merge!({ cf_customer_status: options[:customer_status] }) if options[:customer_status].present?

      attributes.merge!({ amount: options[:amount] }) if options[:amount].present?

      fs_update('deal', open_deal[:id], attributes)
    end

    def mark_deals_status(deals, status)
      return if deals.empty?

      deal_ids = deals.map{ |i| i[:id] }
      data     = { custom_field: { cf_customer_status: status } }
      fs_bulk_update('deal', deal_ids, data)
    end

    def deals_by_account_and_product(deals, account_id, product_id)
      deals.select{ |deal| deal[:deal_product_id] == product_id && 
                           deal[:custom_field][:cf_account_id] == account_id }
    end

    def recent_open_deal(deals, deal_stages)
      return nil if deals.blank?

      open_stages = deal_stages.reject{|stage| [WON_DEAL_STAGE, LOST_DEAL_STAGE].include?(stage[:forecast_type]) }
      open_stage_ids = open_stages.collect{ |stage| stage[:id] }

      open_deals = deals.select{ |deal| open_stage_ids.include?(deal[:deal_stage_id]) }
      recently_updated(open_deals)
    end

    def recent_lead_by_account_and_product(leads, account_id, product_id)
      leads_of_same_prod = leads.select{ |lead| lead[:deal].try(:[], :deal_product_id) == product_id && 
                                                lead[:custom_field][:cf_account_id] == account_id }
      recently_updated(leads_of_same_prod)
    end

    def recently_updated(entities)
      entities.sort_by { |entity| entity[:updated_at] }.last
    end

    def get_all(entity_type)
      config = {  rest_url: SELECTOR_URL % { entity_type: entity_type }, method: 'get' }
      status, result = request_freshsales(config)
      result[entity_type.to_sym]
    end

    def search_accounts_by_name(name, includes='')
      search({ entities: 'sales_account', field: 'name', query: name, includes: includes })
    end

    def search_leads_by_company_name(name, includes='')
      search({ entities: 'lead', field: 'company_name', query: name, includes: includes })
    end

    def search_deals_by_account_and_product(account_id, product_id, includes='')
      results = search({ entities: 'deal', field: 'cf_account_id', query: account_id, includes: includes })
      results[:deals] = results[:deals].select{ |deal| deal[:deal_product_id] == product_id }
      results
    end


    def search_leads_by_account_and_product(account_id, product_id, includes='')
      results = search({ entities: 'lead', field: 'cf_account_id', query: account_id, includes: includes })
      results[:leads] = results[:leads].select{ |lead| lead[:deal].try(:[], :deal_product_id) == product_id }
      results
    end

    def search(options)
      options[:query] = ERB::Util.url_encode(options[:query])
      config = { rest_url: LOOKUP_URL % options, method: 'get' }

      status, response = request_freshsales(config)
      response.inject({}) { |hash, (k,v)| hash.merge(v) }
    end

    def fs_get(type, id, includes)
      config = {  rest_url: "/#{type.pluralize}/#{id}.json?include=#{includes}", method: 'get' }
      request_freshsales(config)
    end

    def fs_create(type, data)
      config = {  rest_url: "/#{type.pluralize}", method: 'post', body: { "#{type}" => data } }
      request_freshsales(config)
    end

    def fs_update(type, id, data)
      config = {  rest_url: "/#{type.pluralize}/#{id}", method: 'put', body: { "#{type}" => data } }
      request_freshsales(config)
    end

    def fs_bulk_update(type, ids, data)
      config = {  rest_url: "/#{type.pluralize}/bulk_update", method: 'put', body: { "#{type}" => data, "ids" => ids } }
      request_freshsales(config)
    end

    def request_freshsales(options)
      proxy = HttpRequestProxy.new
      params = {
        domain: AppConfig['freshsales'][Rails.env]['portal_url'], 
        content_type: 'application/json',
        encode_url: false,
        rest_url: options[:rest_url], body: options[:body].to_json || {}
      }

      authentication_token = AppConfig['freshsales'][Rails.env]['authentication_token']
      request_params = {
        auth_header: "Token token=#{authentication_token}",
        method: options[:method]
      }
      response = proxy.fetch_using_req_params(params, request_params)
      raise "Error occured while requesting Freshsales status:: #{response[:status]} 
                                          account:: #{Account.current.id}" unless response[:status].eql?(200)

      response_content = symbolize_response(JSON.parse(response[:text]))      
      [response[:status], response_content]
    rescue => e
      NewRelic::Agent.notice_error(e)
    end

    def symbolize_response(obj)
      case obj
      when Array
        obj.inject([]){|res, val|
          nval = (val.is_a?(Hash) || val.is_a?(Array)) ? symbolize_response(val) : val
          res << nval
          res
        }
      when Hash
        obj.inject({}){|res, (key, val)|
          nval = (val.is_a?(Hash) || val.is_a?(Array)) ? symbolize_response(val) : val
          res[key.to_sym] = nval
          res
        }
      else
        obj
      end
    end

end