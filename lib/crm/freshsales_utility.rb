class CRM::FreshsalesUtility

  NEGATIVE_LEAD_STAGES    = ['Unqualified']

  PRODUCT_NAME            = AppConfig['app_name']

  WON_DEAL_STAGE          = 'Closed Won'

  LOST_DEAL_STAGE         = 'Closed Lost'

  PAYMENT_STATUS          = { online: "Online", offline: "Offline" }

  LOOKUP_URL              = "/lookup.json?f=%{field}&entities=%{entities}&q=%{query}&include=%{includes}&per_page=100"

  SELECTOR_URL            = "/selector/%{entity_type}"

  CUSTOMER_STATUS         = {
                              trial: 'Trial', suspended: 'Trial Expired', free: 'Free',
                              paid: 'Customer', active: 'Active',
                              no_payment_suspended: 'Suspended', trial_extended: 'Trial Extended',
                              deleted: 'Deleted'
                            }

  DEAL_TYPES              = { new_business: 'New Business', upgrade: 'Existing Business-Upgrade',
                              downgrade: 'Existing Business-Downgrade',
                              renewal: 'Existing Business-Renewal',
                              free: 'Free' }

  OFFLINE                 = 'off'

  NONE                    = 'None'

  ZERO                    = 0

  DEFAULT_ACCOUNT_MANAGER = { display_name:   "Bobby",
                              email:          "eval@freshdesk.com" }

  SUCCESS_CODES = (200...300).to_a
  ADMIN_BASIC_INFO_KEYS = [:first_name, :last_name, :work_number, :email, :country, :job_title, :twitter, :facebook, :linkedin, :time_zone]
  EMPLOYMENT_COUNT = [10001, 5001,1001,501,201,51,11,1, 0]
  COMPANY_INDUSTRY_MAPPING  = YAML.load_file(File.join(Rails.root, 'config', 'company_industries.yml'))

  def initialize(data)
    @account = data[:account]
    @subscription = data[:subscription]
    @cmrr = data[:cmrr]

    @deal_product_id = get_entity_id('deal_products', :name, PRODUCT_NAME)
  end

  def request_account_info(domain, auth_token)
    rest_url = '/sessions.json?include=account'
    config = { rest_url: rest_url, method: 'get', domain: domain, auth_token: auth_token }
    request_freshsales(config)
  end

  def push_signup_data(data)
    @source_and_campaign_info = get_lead_source_and_campaign_id

    # assign leads based on email domain and farming account flag.
    # If the leads email domain is already associated with an account & if it is farming account,
    # then assign new lead to the owner of the respective account.
    # user_domain = @account.admin_email.gsub(/.+@([^.]+).+/, '\1')

    farming_account = get_farming_account(@account.admin_email)

    if farming_account
      # Updating the sales account's owner ID to leads if its the farming account, irrespective of the account's updated_at value.
      updated_at = Time.now.strftime("%Y-%m-%dT%H:%M:%S%:z") # To reuse the create_lead_with_same_owner method, Adding updated_at value as current datatime.
      status,response = create_lead_with_same_owner(farming_account[:owner_id], updated_at)
      Rails.logger.info "Signup Freshsales :: #{@account.id} :: status :: #{status} :: response :: #{response.inspect} :: Updating Owner"
    else
      result = search({ entities: 'lead,contact', field: 'email', query: @account.admin_email,
                      includes: 'owner,lead_stage' })
      lead = recently_updated(result[:leads])
      contact = result[:contacts].first

      if contact
        status, response = create_lead_with_same_owner(contact[:owner_id], contact[:updated_at])
        Rails.logger.info "Signup Freshsales :: #{@account.id} :: status :: #{status} :: response :: #{response.inspect} :: Lead with same Owner"
      elsif lead
        status, response = create_or_update_lead(lead, result[:lead_stages])
        Rails.logger.info "Signup Freshsales :: #{@account.id} :: status :: #{status} :: response :: #{response.inspect} :: create of Update Owner"
      else
        sales_account = search_accounts_by_name(@account.name, 'owner')[:sales_accounts].first
        if sales_account
          status, response = create_lead_with_same_owner(sales_account[:owner_id], sales_account[:updated_at])
          Rails.logger.info "Signup Freshsales :: #{@account.id} :: status :: #{status} :: response :: #{response.inspect} :: Lead with same Owner"
        else
          company_leads = search_leads_by_company_name(@account.name, 'owner')[:leads]
          company_lead  = recent_lead_by_account_and_product(company_leads, @account.id, @deal_product_id)
          status, response = company_lead ? create_lead_with_same_owner(company_lead[:owner_id], company_lead[:updated_at]) :
                                            fs_create('lead', new_lead_params)
          Rails.logger.info "Signup Freshsales :: #{@account.id} :: status :: #{status} :: response :: #{response.inspect} :: create or Lead withn same Owner"
        end
      end
    end

    if success_status?(status) && data[:fs_cookie].present?
      visitor_info = { cookie: data[:fs_cookie], product_id: @deal_product_id }
      config = { rest_url: "/leads/#{response[:lead][:id]}/associate_to_visitor", method: 'post', body: visitor_info }
      request_freshsales(config)
    end
  end

  # Freshsales search by the field email_domain (cf_email_domain)

  def search_accounts_by_email_domain(email)
    user_domain = "@" + Mail::Address.new(email).domain
    sales_account_by_email_domain = search({ entities: 'sales_account', field: 'cf_email_domain', query: user_domain,  includes: "" })[:sales_accounts]
  end

  # Get the recently updated farming account for the given email domain.

  def get_farming_account(email)
    sales_account_by_email_domain = search_accounts_by_email_domain(email)
    account_data = sales_account_by_email_domain.select {|x| x[:custom_field][:cf_is_farming_account] == true }.last
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
        associate_deals_to_contact(result[:deals], response[:contact][:id]) if success_status?(status)
      end
    else
      leads = search_leads_by_account_and_product(@account.id, @deal_product_id, 'owner')[:leads]
      if leads.any?
        recent_lead = recently_updated(leads)
        admin_leads = leads.select{ |lead| lead[:email] == @account.admin_email }
        admin_leads.any? ? fs_update('lead', recently_updated(admin_leads)[:id], admin_basic_info) :
                           create_lead_with_same_owner(recent_lead[:owner_id], recent_lead[:updated_at])
      else
        raise "No leads found for the account #{@account.id}"
      end
    end
  end

  def push_subscription_changes(deal_type, amount, payments_count, state_changed)
    Rails.logger.debug "In FreshsalesUtility::push_subscription_changes :: deal_type :: #{deal_type} :: amount :: #{amount}"

    result = search_deals_by_account_and_product(@account.id, @deal_product_id, 'sales_account,deal_stage,deal_type,deal_product,contacts')
    customer_status = get_customer_status(@subscription[:state].to_sym, payments_count)
    @won_deal_stage_id = get_entity_id('deal_stages', :forecast_type, WON_DEAL_STAGE)

    if result[:deals].any?
      deal_type = ((deal_type == :new_business) && get_closed_new_business_deal(result[:deals]).present?) ? :upgrade : deal_type
      open_deal = (deal_type == :downgrade) ? nil : recent_open_deal(result[:deals], result[:deal_stages])
      if open_deal
        mark_deal_as_closed_won(open_deal, { deal_type: deal_type, amount: amount })
      else
        deal_account_id = result[:sales_accounts].find{ |acc| acc[:id] == result[:deals].first[:sales_account_id] }[:id]
        deal_params = { deal_type: deal_type, amount: amount, customer_status: customer_status,
                        sales_account_id: deal_account_id }.merge(contact_and_owner(deal_account_id))
        create_deal_and_close(deal_params)
      end
      if state_changed
        data = { custom_field: { cf_customer_status: customer_status } }
        mark_customer_status(result[:deals], data)
      end
    else
      leads = search_leads_by_account_and_product(@account.id, @deal_product_id)[:leads]

      admin_leads = leads.select{|lead| lead[:email] == @account.admin_email }
      admin_lead  = recently_updated(admin_leads)
      lead_params = { deal_type: deal_type, amount: amount, customer_status: customer_status }
      admin_lead  ? convert_lead_and_close_deal(admin_lead, lead_params) : create_lead_and_convert_and_close_deal(lead_params)

      other_leads_of_account = admin_lead.nil? ? leads : (leads - [admin_lead])
      other_leads_of_account.each{|lead| convert_lead(lead, {customer_status: customer_status}) }
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
      data = @account.account_configuration.contact_info.slice(*ADMIN_BASIC_INFO_KEYS)
      data[:company] = account_basic_info
      data[:last_name]||= @account.admin_first_name
      data[:work_number] = @account.admin_phone
      data[:custom_field] = { cf_domain_name: @account.full_domain }
      data.merge!(@source_and_campaign_info) if @source_and_campaign_info
      data
    end

    def account_basic_info
      {
          name: @account.name, address: @account.account_configuration.company_info.try(:[], :location).try(:[], :streetName),
          city: @account.account_configuration.company_info.try(:[], :location).try(:[], :city),
          state: @account.account_configuration.company_info.try(:[], :location).try(:[], :state),
          zipcode: @account.account_configuration.company_info.try(:[], :location).try(:[], :postalCode),
          country: @account.account_configuration.company_info.try(:[], :location).try(:[], :country),
          industry_type_id: company_industry_type_id(@account.account_configuration.company_info[:industry]),
          number_of_employees: employment_value(@account.account_configuration.company_info.try(:[], :metrics).try(:[], :employees)),
          phone: @account.account_configuration.company_info.fetch(:phone_numbers, []).join(","),
          annual_revenue: @account.account_configuration.company_info.try(:[], :metrics).try(:[], :annualRevenue)
      }
    end

    def employment_value(employment_count)
      return unless employment_count && (employment_count.is_a? Integer)
      EMPLOYMENT_COUNT.each do |i|
        return i if employment_count >= i
      end
    end

    def company_industry_type_id(company_industry)
      COMPANY_INDUSTRY_MAPPING.try(:[], company_industry).try(:[], "id")
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
      conversion_metric = @account.conversion_metric
      lead_attrs = admin_basic_info.merge({
        custom_field: {
          cf_account_id:  @account.id, 
          cf_domain_name: @account.full_domain, 
          cf_reputation_score: @account.ehawk_reputation_score,
          cf_google_analytics_client_id: conversion_metric.try(:ga_client_id),
          cf_signup_type: conversion_metric.try(:signup_method)
        }
      })
      acc_metrics = account_metrics
      subscription_attrs = new_lead_subscription_params

      lead_attrs[:deal] = subscription_attrs[:deal_attrs]
      lead_attrs.merge!(acc_metrics[:lead_attrs])
      lead_attrs[:custom_field].merge!(acc_metrics[:custom_attrs].merge(subscription_attrs[:custom_attrs]))

      lead_attrs
    end

    def won_deal_params
      {
        deal_stage_id: @won_deal_stage_id,
        deal_payment_status_id: payment_status_id,
        custom_field: {
          cf_number_of_agents: @subscription[:agent_limit],
          cf_plan: SubscriptionPlan.find_by_id(@subscription[:subscription_plan_id]).try(:name),
          cf_customer_status: CUSTOMER_STATUS[@subscription[:state].to_sym],
          cf_domain_name: @account.full_domain,
          cf_signup_date: @subscription[:created_at].strftime("%Y-%m-%d"),
          cf_renewal_period: fetch_renewal_period.humanize
        }
      }
    end

    def contact_and_owner(sales_account_id)
      params = {}
      status, account_result = fs_get('sales_account', sales_account_id, 'owner,contacts')
      if success_status?(status)
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

    def get_closed_new_business_deal(deals)
      type_id = get_entity_id('deal_types', :name, "New Business")
      deals.find{ |deal| deal[:deal_type_id] == type_id  && deal[:deal_stage_id] == @won_deal_stage_id }
    end

    def update_deal_or_lead(data)
      result    = search_deals_by_account_and_product(@account.id, @deal_product_id, 'deal_product,contacts')

      if result[:deals].any?
        deal_ids = result[:deals].map{ |i| i[:id] }
        fs_bulk_update('deal', deal_ids, data) if deal_ids.any?
        mark_customer_status(result[:deals], data)
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
          data = {
            deal: { deal_product_id: @deal_product_id },
            custom_field: { cf_account_id: @account.id, cf_domain_name: @account.full_domain }
          }
          data.merge!(@source_and_campaign_info)
          fs_update('lead', lead[:id], data)
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
        custom_field: attributes[:custom_field].merge({ cf_account_id: @account.id,
                                                        cf_customer_status: options[:customer_status],
                                                        cf_presales_contact: NONE,
                                                        cf_renewal_period: fetch_renewal_period.humanize})
      })

      attributes.merge!({ contacts_added_list: [options[:contact_id]] }) if options[:contact_id]

      fs_create('deal', attributes)
    end

    def create_lead_and_convert_and_close_deal(options)
      lead_info        = new_lead_params

      config = { rest_url: "/sessions", method: 'get' }
      user_status, user_response = request_freshsales(config)
      lead_info[:owner_id] = user_response[:user][:id] if success_status?(user_status)

      status, response = fs_create('lead', lead_info)
      convert_lead_and_close_deal(response[:lead], { deal_type: options[:deal_type],
                                                     amount: options[:amount],
                                                     customer_status: options[:customer_status] }) if success_status?(status)
    end

    def convert_lead_and_close_deal(lead, options)
      convert_status, convert_response = convert_lead(lead, options)
      return unless success_status?(convert_status)

      status, response = fs_get('contact', convert_response[:contact][:id], 'deals')
      if success_status?(status)
        deals = deals_by_account_and_product(response[:deals], @account.id, @deal_product_id)
        open_deal = recent_open_deal(deals, response[:deal_stages])
        mark_deal_as_closed_won(open_deal, { deal_type: options[:deal_type], customer_status: options[:customer_status] })
      end
    end

    def convert_lead(lead, options={})
      if lead[:custom_field][:cf_presales_contact].blank?
        status, response = fs_update('lead', lead[:id], { custom_field: { cf_presales_contact: NONE } })
        return [status, response] unless success_status?(status)
      end

      data = { last_name: lead[:last_name], email: lead[:email], company: { name: lead[:company][:name] } }

      if options.present? && options[:deal_type].present? && options[:amount].present?
        data.merge!({deal: { name: deal_name(@account.full_domain, options[:deal_type]), amount: options[:amount] }})
      end
      config = { rest_url: "/leads/#{lead[:id]}/convert", method: 'post', body: { 'lead' => data } }
      status,response = request_freshsales(config)
      fs_update('contact', response[:contact][:id], { custom_field:
                              { cf_customer_status: options[:customer_status] } }) if success_status?(status)
      [status, response]
    end

    def mark_deal_as_closed_won(open_deal, options)
      attributes = won_deal_params

      if options[:deal_type].present?
        deal_type_id = get_entity_id('deal_types', :name, DEAL_TYPES[options[:deal_type]])
        attributes.merge!({ deal_type_id: deal_type_id })
      end
      attributes[:custom_field].merge!({ cf_customer_status: options[:customer_status] }) if options[:customer_status].present?
      attributes[:custom_field].merge!({ cf_presales_contact: NONE }) if open_deal[:custom_field][:cf_presales_contact].blank?

      attributes.merge!({ amount: options[:amount]}) if options[:amount].present?

      attributes.merge!({cf_renewal_period: fetch_renewal_period.humanize})

      fs_update('deal', open_deal[:id], attributes)
    end

     def mark_customer_status(deals, data)
      deal_ids = deals.map{ |i| i[:id] }
      fs_bulk_update('deal', deal_ids, data)
      data[:custom_field].delete(:cf_trial_expiry_date)#in case of trial_extension - contacts have no cf_trial_expiry_date
      contact_ids = deals.map{ |i| i[:contact_ids] }.flatten.uniq
      fs_bulk_update('contact', contact_ids, data) if contact_ids.any?
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

    def get_lead_source_and_campaign_id
      config = {  rest_url: "/settings/leads/fields", method: 'get' }
      status,response = request_freshsales(config)
      source = response[:fields].detect {|s| s.try(:[],:name) == "lead_source_id"}
      campaign = response[:fields].detect {|s| s.try(:[],:name) == "campaign_id"}
      new_source = source[:choices].detect { |n| n.try(:[], :value) == (@account.conversion_metric.lead_source_choice.presence || 'Inbound') }
      source_id = new_source.present? ? new_source[:id] : source[:choices].detect { |n| n.try(:[], :value) == 'Inbound' }[:id]
      campaign_id = campaign[:choices].detect{|n| n.try(:[],:value) == "Trial Signup"}[:id]
      { lead_source_id: source_id, campaign_id: campaign_id }
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
        domain: options[:domain] || AppConfig['freshsales'][Rails.env]['portal_url'],
        content_type: 'application/json',
        encode_url: false,
        rest_url: options[:rest_url], body: options[:body].to_json || {}
      }

      authentication_token = options[:auth_token] || AppConfig['freshsales'][Rails.env]['authentication_token']
      request_params = {
        auth_header: "Token token=#{authentication_token}",
        method: options[:method]
      }
      response = proxy.fetch_using_req_params(params, request_params)
      Rails.logger.info "Signup Freshsales :: params :: #{params.inspect} request_params :: #{request_params.inspect} :: Lead create req"
      raise "Error occured while requesting Freshsales status:: #{response[:status]}
                                          account:: #{Account.current.id}" unless success_status?(response[:status])

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

    def success_status?(status)
      status.in?(SUCCESS_CODES)
    end

    def fetch_renewal_period
      Billing::Subscription::BILLING_PERIOD[@account.subscription.renewal_period]
    end

end
