class SubscriptionAffiliate < ActiveRecord::Base

  not_sharded

  has_many :subscriptions
  has_many :subscription_payments

  KEY_TERMS = { 
    :shareasale => "SSAID",
    :freshdesk_partners => "FDRES", 
    :grasshopper => "grasshopper" 
  }
  
  SHAREASALE = { 
    :name => "Share A Sale", 
    :commission => 0.20, 
    :merchant_id => 40631
  }
  
  AFFILIATE_PARAMS = KEY_TERMS.collect { |affiliate, key_term| key_term }

  validates_presence_of :token
  validates_uniqueness_of :token
  validates_numericality_of :rate, :greater_than_or_equal_to => 0,
    :less_than_or_equal_to => 1

  class << self
    def has_affiliate_param?(metrics)
      !metrics.nil? and  affiliate_type(metrics)
    end

    def affiliate_param(url)
      AFFILIATE_PARAMS.select { |param| url.include?(param) }.to_s
    end

    def affiliate_type(metrics)
      (affiliate_param(metrics.referrer) || affiliate_param(metrics.first_referrer))
    end

  def check_affiliate_in_metrics?(account,shareasale_affiliate_id)
    data = get_metrics_data(account)
    case affiliate_param(data[:uri])
      when KEY_TERMS[:shareasale]
        check_shareasale_token(data,shareasale_affiliate_id)
      when KEY_TERMS[:freshdesk_partners] 
        get_reseller_token(data)
      when KEY_TERMS[:grasshopper]
        get_grasshopper_token(data)
      else
        nil
    end
  end

  def check_shareasale_affiliate_in_metrics(data,shareasale_affiliate_id)
    affiliate_id = data[:params].fetch(affiliate_param[:uri])
    affiliate_id and (affiliate_id.eql?(shareasale_affiliate_id))
  end

  def get_grasshopper_token(data)
    data[:params].fetch(affiliate_param(data[:uri]))
  end

  def get_fdres_token(data)
    data[:params]
  end

  def attach_affiliate(account,affiliate_id)
    begin
      affiliate = find_by_token(affiliate_id)
      if affiliate.blank? and is_share_a_sale?(account)
        affiliate = create_new_affiliate(affiliate_id) #only for Share a Sale..
      end
      account.subscription.affiliate = affiliate
      account.subscription.save! unless account.subscription.active?
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      FreshdeskErrorsMailer.deliver_error_email(nil,nil,e,{:subject => "Error creating subscription affiliate"})
    end
  end


  def create_new_affiliate(affiliate_id) 
    create( :name => SHAREASALE[:name],
            :rate => SHAREASALE[:commission],
            :token => affiliate_id )
  end

  

  def add_affiliate_for_share_a_sale(account,affiliate_id)
    if check_affiliate_in_metrics?(account,affiliate_id)
      affiliate = create(affiliate_id)
    end
  end
  end  
  # Return the fees owed to an affiliate for a particular time
  # period. The period defaults to the previous month.
  def fees(period = (Time.now.beginning_of_month - 1).beginning_of_month .. (Time.now.beginning_of_month - 1).end_of_month)
    subscription_payments.all(:conditions => ["created_at > '#{1.year.ago}'"]).collect(&:affiliate_amount).sum    
  end


  private

    def is_share_a_sale?(account)
      affiliate_type(account.conversion_metric).eql?("SSAID")
    end

    def get_metrics_data(account)
      metrics = account.conversion_metric
      if has_affiliate_param?(metrics)
        uri = (affiliate_param(metrics.referrer) ? metrics.referrer : metrics.first_referrer).tr('+','_').delete("\n")
        params = Rack::Utils.parse_query(URI.parse(uri).query)
        params.each_pair { |key,value| @params[key] = value.tr('_','+') }
      end
      return { :uri => uri, :params => params }
    end

end
