class CRM::FreshsalesUtility

  NEGATIVE_LEAD_STAGES  = ['Unqualified']

  PRODUCT_NAME          = 'Freshdesk'

  WON_DEAL_STAGE        = 'Closed Won'

  LOST_DEAL_STAGE       = 'Closed Lost'

  PAYMENT_STATUS        = { online: "Online", offline: "Offline" }

  LOOKUP_URL            = "/lookup.json?f=%{field}&entities=%{entities}&q=%{query}&include=%{includes}"

  SELECTOR_URL          = "/selector/%{entity_type}"

  CUSTOMER_STATUS       = { trial: 'Trial', suspended: 'Trial Expired', free: 'Free', 
                            paid: 'Customer', deleted: 'Deleted', active: 'Active', 
                            no_payment_suspended: 'Suspended' }

  DEAL_TYPES            = { new_business: 'New Business', upgrade: 'Existing Business-Upgrade', 
                            downgrade: 'Existing Business-Downgrade', 
                            renewal: 'Existing Business-Renewal' }

  ACTIVE                = 'active'

  OFFLINE               = 'off'

  def initialize(account)
    @account = account
    @subscription = account.subscription
    @deal_product_id = get_entity_id('deal_products', :name, PRODUCT_NAME)
  end

  def push_signup_data
    result = search({ entities: 'lead,contact', field: 'email', query: @account.admin_email, 
                      includes: 'owner,lead_stage' })

    lead = recently_updated(result[:leads])
    contact = result[:contacts].first

    if contact
      create_lead_with_same_owner(contact[:owner_id])
    elsif lead
      create_or_update_lead(lead, result[:lead_stages])
    else
      sales_account = search_accounts_by_name(@account.name, 'owner')[:sales_accounts].first
      if sales_account
        create_lead_with_same_owner(sales_account[:owner_id])
      else
        company_leads = search_leads_by_company_name(@account.name, 'owner')[:leads]
        company_lead  = recent_lead_of_same_product(company_leads)
        company_lead  ? create_lead_with_same_owner(company_lead[:owner_id]) : fs_create('lead', new_lead_params)
      end
    end
  end

  def update_admin_info
    result = search_accounts_by_name(@account.name, 'contacts,deals')
    sales_account = result[:sales_accounts].first

    if sales_account
      contact = result[:contacts].find{ |contact| contact[:email] == @account.admin_email }
      if contact
        fs_update('contact', contact[:id], admin_basic_info)
      else
        contact_info = admin_basic_info.merge({ sales_account_id: sales_account[:id] })
        status, response = fs_create('contact', contact_info)
        associate_deals_to_contact(@account.id, response[:contact][:id], result[:deals]) if status.eql?(200)
      end
    else
      company_leads = search_leads_by_company_name(@account.name, 'owner')[:leads]
      company_lead  = recent_lead_of_same_product(company_leads)
      if company_lead
        (company_lead[:email] == @account.admin_email) ? fs_update('lead', company_lead[:id], admin_basic_info) :
                                                         create_lead_with_same_owner(company_lead[:owner_id])
      else
        fs_create('lead', new_lead_params)
      end
    end
  end

  def account_upgrade(old_subscription)
    deal_type = :upgrade
    result = search_deals_by_cf_account_id(@account.id, 'sales_account,deal_stage,deal_product')

    if result[:deals].any?
      open_deal = recent_open_deal(@account.id, result[:deals], result[:deal_stages])
      if open_deal
        mark_deal_as_closed_won(open_deal, { deal_type: deal_type, old_subscription: old_subscription })
      else
        deal_account = result[:sales_accounts].find{ |acc| acc[:id] == result[:deals].first[:sales_account_id] }
        account_result = search_accounts_by_name(deal_account[:name], 'owner,contacts')
        account_contact = account_result[:contacts].find{ |cont| cont[:email] == @account.admin_email }

        create_deal_and_close({ sales_account: account_result[:sales_accounts].first, contact: account_contact, 
                                deal_type: deal_type, old_subscription: old_subscription })
      end
    else
      create_lead_and_convert_and_close_deal({ deal_type: deal_type, old_subscription: old_subscription })
    end
  end

  def account_downgrade(old_subscription)
    deal_type = :downgrade
    result = search_deals_by_cf_account_id(@account.id, 'sales_account,deal_stage,deal_product')

    if result[:deals].any?
      deal_account = result[:sales_accounts].find{ |acc| acc[:id] == result[:deals].first[:sales_account_id] }
      account_result = search_accounts_by_name(deal_account[:name], 'owner,contacts')
      account_contact = account_result[:contacts].find{ |cont| cont[:email] == @account.admin_email }

      create_deal_and_close({ sales_account: account_result[:sales_accounts].first, contact: account_contact, 
                              deal_type: deal_type, old_subscription: old_subscription })
    else
      create_lead_and_convert_and_close_deal({ deal_type: deal_type, old_subscription: old_subscription })
    end
  end

  def account_activation(payment_info)
    collection_date = (payment_info[:auto_collection] == OFFLINE && payment_info[:collection_date].present?) ? 
                                            Time.at(payment_info[:collection_date]).to_datetime.utc : nil

    result = search_deals_by_cf_account_id(@account.id, 'sales_account,deal_stage,deal_product')

    if result[:deals].any? && (open_deal = recent_open_deal(@account.id, result[:deals], result[:deal_stages]))
      mark_deal_as_closed_won(open_deal, { collection_date: collection_date })
    else
      deal_type = :new_business
      leads = search_leads_by_email(@account.admin_email)[:leads]
      lead  = recent_lead_of_same_product(leads)
      lead  ? convert_lead_and_close_deal(lead, { deal_type: deal_type, collection_date: collection_date }) :
              create_lead_and_convert_and_close_deal({ deal_type: deal_type, collection_date: collection_date })
    end
  end

  def update_customer_status(old_subscription)
    current_state       = @subscription.state.to_sym
    customer_status     = (current_state == :suspended && @subscription.subscription_payments.count > 0) ? 
                                  CUSTOMER_STATUS[:no_payment_suspended] : CUSTOMER_STATUS[current_state]
    (deal_type, amount) = deal_type_and_amount_for_status_change(old_subscription, current_state)

    result = search_deals_by_cf_account_id(@account.id, 'sales_account')

    if result[:deals].any?
      deal_account = result[:sales_accounts].find{ |acc| acc[:id] == result[:deals].first[:sales_account_id] }
      account_result = search_accounts_by_name(deal_account[:name], 'owner,contacts')
      account_contact = account_result[:contacts].find{ |cont| cont[:email] == @account.admin_email }

      create_deal_and_close({ sales_account: account_result[:sales_accounts].first, contact: account_contact, 
                              deal_type: deal_type, customer_status: customer_status, amount: amount })
      mark_deals_status(result[:deals], customer_status)
    else
      leads = search_leads_by_email(@account.admin_email)[:leads]
      lead  = recent_lead_of_same_product(leads)
      lead  ? convert_lead_and_close_deal(lead, { deal_type: deal_type, customer_status: customer_status, 
                                                  amount: amount }) :
              create_lead_and_convert_and_close_deal({ deal_type: deal_type, customer_status: customer_status, 
                                                       amount: amount })
    end
  end

  private

    def admin_basic_info
      { first_name: @account.admin_first_name, last_name: @account.admin_last_name,
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
          cf_agent_count: @subscription.agent_limit, 
          cf_customer_status: CUSTOMER_STATUS[@subscription.state.to_sym],
          cf_signup_date: @subscription.created_at.strftime("%Y-%m-%d")
        },
        deal_attrs: {
          name: deal_name(@account.full_domain, :new_business),
          amount: @subscription.cmrr.round(2),
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
          cf_number_of_agents: @subscription.agent_limit,
          cf_plan: @subscription.plan_name,
          cf_customer_status: CUSTOMER_STATUS[@subscription.state.to_sym]
        }
      }
    end

    def get_entity_id(entity_type, find_by, query_str)
      entities = get_all(entity_type)
      entities.find{ |entity| entity[find_by.to_sym] == query_str }.try(:[], :id)
    end

    def deal_name(domain, type)
      "#{domain} - #{DEAL_TYPES[type.to_sym]}" 
    end

    def deal_type_and_amount_for_status_change(old_subscription, current_state)
      old_state = old_subscription[:state].to_sym

      upgrade = (old_state == :suspended && current_state == :active) || (old_state == :free && current_state == :active)
      free    = (old_state == :trial && current_state == :free) || (old_state == :suspended && current_state == :free)

      (deal_type, amount) = case
                            when upgrade 
                              [:upgrade, @subscription.cmrr.round(2)]
                            when free
                              [:new_business, 0]
                            when (old_state == :trial && current_state == :active)
                              [:new_business, @subscription.cmrr.round(2)]
                            when (old_state == :trial && current_state == :suspended)
                              [:downgrade, 0]
                            when (old_state == :active && current_state == :suspended)
                              amount = (@subscription.amount = 0) ? calculate_deal_amount(old_subscription) : 
                                                                    -@subscription.cmrr.round(2)
                              [:downgrade, amount]
                            end
    end

    def payment_status_id
      return nil if @subscription.amount == 0

      status = @subscription.card_number.blank? ? :offline : :online
      get_entity_id('deal_payment_statuses', :name, PAYMENT_STATUS[status])
    end

    def create_or_update_lead(lead, stages)
      if lead_in_negative_stage?(lead, stages)
        fs_create('lead', new_lead_params)
      else
        if lead[:deal][:deal_product_id].blank?
          deal_info = { 
            deal: { deal_product_id: @deal_product_id }, 
            custom_field: { cf_account_id: @account.id, cf_domain_name: @account.full_domain }
          }
          fs_update('lead', lead[:id], deal_info)
        else
          create_lead_with_same_owner(lead[:owner_id])
        end
      end
    end

    def lead_in_negative_stage?(lead, stages)
      stage_name = stages.find{ |stage| stage[:id] == lead[:lead_stage_id] }.try(:[], :name)
      stage_name.in?(NEGATIVE_LEAD_STAGES)
    end

    def create_lead_with_same_owner(owner_id) 
      lead_info = new_lead_params.merge({ owner_id: owner_id })
      fs_create('lead', lead_info)
    end

    def associate_deals_to_contact(account_id, contact_id, deals)
      deal_ids = deals.select{ |deal| 
                  deal[:deal_product_id] == @deal_product_id && 
                  deal[:custom_field][:cf_account_id] == account_id }.map!{ |deal| deal[:id] }

      deal_ids.each do |deal_id|
        deal_info = { contacts_added_list: [contact_id] }
        fs_update('deal', deal_id, deal_info)
      end
    end

    def create_deal_and_close(options)
      attributes   = won_deal_params
      owner_id     = options[:contact] ? options[:contact][:owner_id] : options[:sales_account][:owner_id]
      deal_type_id = get_entity_id('deal_types', :name, DEAL_TYPES[options[:deal_type]])
      deal_amount  = options[:amount] || calculate_deal_amount(options[:old_subscription])

      attributes.merge!({
        name: deal_name(@account.full_domain, options[:deal_type]),
        amount: deal_amount,
        deal_product_id: @deal_product_id, 
        sales_account_id: options[:sales_account][:id],
        owner_id: owner_id,
        deal_type_id: deal_type_id,
        custom_field: attributes[:custom_field].merge({ cf_account_id: @account.id })
      })

      attributes[:custom_field].merge!({ cf_customer_status: options[:customer_status] }) if options[:customer_status]
      attributes.merge!({ contacts_added_list: [options[:contact][:id]] }) if options[:contact]

      fs_create('deal', attributes)
    end
 
    def create_lead_and_convert_and_close_deal(options)
      lead_info        = new_lead_params
      lead_deal_name   = deal_name(@account.full_domain, options[:deal_type])
      lead_deal_amount = options[:amount] 
      lead_deal_amount ||= options[:old_subscription].present? ? calculate_deal_amount(options[:old_subscription]) : 
                                                                 @subscription.cmrr.round(2)
      lead_info.merge!({
        deal: lead_info[:deal].merge({ name: lead_deal_name, amount: lead_deal_amount })
      })
      lead_info[:custom_field].merge!({ cf_customer_status: options[:customer_status] }) if options[:customer_status].present?
      lead_info[:custom_field].merge!({ cf_collection_date: options[:collection_date]}) if options[:collection_date].present?

      config = { rest_url: "/sessions", method: 'get' }
      user_status, user_response = request_freshsales(config)
      lead_info[:owner_id] = user_response[:user][:id] if user_status.eql?(200)

      status, response = fs_create('lead', lead_info)
      convert_lead_and_close_deal(response[:lead], { deal_type: options[:deal_type],
                                                     amount: options[:amount], 
                                                     old_subscription: options[:old_subscription] }) if status.eql?(200)
    end

    def convert_lead_and_close_deal(lead, options)
      lead[:custom_field].merge!({ cf_customer_status: options[:customer_status] }) if options[:customer_status]
      lead[:custom_field].merge!({ cf_collection_date: options[:collection_date]}) if options[:collection_date].present?

      status, response = convert_lead(lead)
      return unless status.eql?(200)

      status, response = fs_get('contact', response[:contact][:id], 'deals')
      if status.eql?(200)
        open_deal = recent_open_deal(@account.id, response[:deals], response[:deal_stages])
        mark_deal_as_closed_won(open_deal, { deal_type: options[:deal_type],
                                             amount: options[:amount],
                                             old_subscription: options[:old_subscription] })
      end
    end

    def convert_lead(lead)
      data = { last_name: lead[:last_name], email: lead[:email],
               company: { name: lead[:company][:name] },
               deal: { name: lead[:deal][:name], amount: lead[:deal][:amount] }
             }
      config = { rest_url: "/leads/#{lead[:id]}/convert", method: 'post', body: { 'lead' => data } }
      request_freshsales(config)
    end

    def mark_deal_as_closed_won(open_deal, options)
      attributes = won_deal_params

      if options[:deal_type].present?
        deal_type_id = get_entity_id('deal_types', :name, DEAL_TYPES[options[:deal_type]])
        attributes.merge!({ deal_type_id: deal_type_id })
      end
      deal_amount = options[:amount]
      deal_amount ||= options[:old_subscription].present? ? calculate_deal_amount(options[:old_subscription]) : 
                                                            @subscription.cmrr.round(2)
      attributes.merge!({ amount: deal_amount })

      attributes[:custom_field].merge!({cf_collection_date: options[:collection_date]}) if options[:collection_date].present?

      fs_update('deal', open_deal[:id], attributes)
    end

    def calculate_deal_amount(old_subscription)
      old_subscription = Subscription.new({ amount: old_subscription[:amount], 
                                            renewal_period: old_subscription[:renewal_period],
                                            subscription_currency_id: @subscription.subscription_currency_id })
      (@subscription.cmrr - old_subscription.cmrr).round(2)
    end

    def mark_deals_status(deals, status)
      deal_ids = deals.map{ |i| i[:id] }
      data     = { custom_field: { cf_customer_status: status } }

      fs_bulk_update('deal', deal_ids, data)
    end

    def recent_open_deal(account_id, deals, deal_stages)
      return nil if deals.blank?

      open_stages = deal_stages.reject{|stage| stage[:forecast_type].in?([WON_DEAL_STAGE, LOST_DEAL_STAGE]) }
      open_stage_ids = open_stages.collect{ |stage| stage[:id] }

      open_deals = deals.select{ |deal| 
                    deal[:deal_product_id] == @deal_product_id && 
                    deal[:custom_field][:cf_account_id] == account_id && 
                    deal[:deal_stage_id].in?(open_stage_ids) }
      recently_updated(open_deals)
    end

    def recent_lead_of_same_product(leads)
      leads_of_same_prod = leads.select{ |lead| lead[:deal][:deal_product_id] == @deal_product_id && 
                                                lead[:custom_field][:cf_account_id] == @account.id }
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

    def search_leads_by_email(email, includes='')
      search({ entities: 'lead', field: 'email', query: email, includes: includes })
    end

    def search_leads_by_company_name(name, includes='')
      search({ entities: 'lead', field: 'company_name', query: name, includes: includes })
    end

    def search_deals_by_cf_account_id(account_id, includes='')
      search({ entities: 'deal', field: 'cf_account_id', query: account_id, includes: includes })
    end

    def search(options)
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