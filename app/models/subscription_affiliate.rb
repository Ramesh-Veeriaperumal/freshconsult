class SubscriptionAffiliate < ActiveRecord::Base
  self.primary_key = :id
  not_sharded
  
  has_many :subscriptions
  has_many :subscription_payments

  has_many :affiliate_discount_mappings
  has_many :discounts, 
    :class_name => 'AffiliateDiscount',
    :through => :affiliate_discount_mappings,
    :source => :affiliate_discount

  validates_presence_of :token
  validates_uniqueness_of :token
  validates_numericality_of :rate, :greater_than_or_equal_to => 0,
    :less_than_or_equal_to => 1

  before_save :set_discounts
  attr_accessor :affiliate_discount_ids

  AFFILIATES = { 
    :shareasale => {
      :name => "Share A Sale",
      :affiliate_param => "SSAID",
      :commission => 0.20, 
      :merchant_id => 40631
    },

    :freshdesk_partner => {
      :name => "Freshdesk Partner",
      :affiliate_param => "FDRES"
    },
    
    :grasshopper => {
      :name => "Grasshopper",
      :affiliate_param => "grasshopper",
      :token => "grasshopper"
    },
    
    :huddlebuy => {
      :name => "Huddle Buy",
      :affiliate_param => "huddlebuy.co.uk/goldcard",
      :token => "huddlebuy"
    },

    :flexjobs => {
      :name => "Flexjobs",
      :affiliate_param => "flexjobs.com/members/employers/savings",
      :token => "flexjobs"
    },

    :dpu => {
      :name => "Digital Publisher University",
      :affiliate_param => "digitalpublisheruniversity.com/offers/freshdesk",
      :token => "dpu"
    },

    :rewardli => {
      :name => "Rewardli",
      :affiliate_param => "rewardli.com/offers/1577-freshdesk-communications-mobile",
      :token => "rewardli"
    } 
  }
  
  AFFILIATE_PARAMS = AFFILIATES.collect { |affiliate, details| details[:affiliate_param] }
  
  
  class << self

    AFFILIATES.each_pair do |affiliate, details|
      define_method "#{affiliate}_subscription?" do |affiliate_param|
        affiliate_param == details[:affiliate_param]
      end
    end

    def affiliate_subscription?(account)
      has_affiliate_param?(account.conversion_metric) if account.conversion_metric
    end
    
    #shareasale
    def subscription_from_shareasale?(account, shareasale_affiliate_id)
      data = fetch_data_from_metrics(account.conversion_metric)
      if (data[:affiliate_param] and shareasale_subscription?(data[:affiliate_param]))
        params = Rack::Request.new(Rack::MockRequest.env_for(data[:uri])).params
        affiliate_id = params.fetch(data[:affiliate_param])
      end

      affiliate_id and (affiliate_id.eql?(shareasale_affiliate_id))
    end

    #other affiliates
    def fetch_affiliate(account)
      data = fetch_data_from_metrics(account.conversion_metric)
      affiliate_param = data[:affiliate_param]

      case 
        when grasshopper_subscription?(affiliate_param)
          find_by_token(AFFILIATES[:grasshopper][:token])
        when huddlebuy_subscription?(affiliate_param)
          find_by_token(AFFILIATES[:huddlebuy][:token])
        when flexjobs_subscription?(affiliate_param)
          find_by_token(AFFILIATES[:flexjobs][:token])
        when dpu_subscription?(affiliate_param)
          find_by_token(AFFILIATES[:dpu][:token])
        when rewardli_subscription?(affiliate_param)
          find_by_token(AFFILIATES[:rewardli][:token])
        when freshdesk_partner_subscription?(affiliate_param)
          fetch_freshdesk_partner(account)
        else
          nil
      end
    end

    def add_affiliate(account, affiliate_token)
      begin
        account.make_current
        affiliate = find_by_token(affiliate_token)
        if affiliate.blank? and subscription_from_shareasale?(account, affiliate_token)
          affiliate = create_shareasale_affiliate(affiliate_token) 
        end
        account.subscription.affiliate = affiliate
        account.subscription.save!
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        FreshdeskErrorsMailer.error_email(nil, nil, e,
          { :subject => "Error attaching affiliate to the subscription" })
      end
    end
    
    private
      def has_affiliate_param?(metrics)
        (affiliate_param(metrics.referrer).present? || 
            affiliate_param(metrics.first_referrer).present?)
      end

      def affiliate_param(url)
        AFFILIATE_PARAMS.select { |param| url.include?(param) }.to_s unless url.blank?
      end

      def fetch_data_from_metrics(metrics)
        if !metrics.blank? and has_affiliate_param?(metrics)
          uri = !affiliate_param(metrics.referrer).blank? ? 
                        metrics.referrer : metrics.first_referrer
          affiliate_param = affiliate_param(uri)
        end

        { :uri => uri, :affiliate_param => affiliate_param }
      end

      def create_shareasale_affiliate(affiliate_id) 
        create( :name => AFFILIATES[:shareasale][:name],
                :rate => AFFILIATES[:shareasale][:commission],
                :token => affiliate_id )
      end

      def fetch_freshdesk_partner(account)
        data = fetch_data_from_metrics(account.conversion_metric)
        params = Rack::Utils.parse_query((URI.parse(data[:uri]).query))
        shared_secret = AppConfig["reseller_portal"]["shared_secret"]
        secret_key = Digest::SHA1.hexdigest(shared_secret+params["TIMESTAMP"])
        token = Encryptor.decrypt(Base64.decode64(params["FDRES"]), :key => secret_key)
        
        find_by_token(token)
      end
  end  

  def set_discounts
    if self.affiliate_discount_ids
      self.affiliate_discount_ids.collect{ |id| id unless id.eql?("---")}.compact
      self.discounts = AffiliateDiscount.retrieve_discounts(self.affiliate_discount_ids)
    end
  end

  def fetch_discount(discount_type)
    discount = AffiliateDiscount.retrieve_discount_with_type(self, discount_type)
    discount.id if discount
  end
  

  # Return the fees owed to an affiliate for a particular time
  # period. The period defaults to the previous month.
  def fees(period = (Time.now.beginning_of_month - 1).beginning_of_month .. (Time.now.beginning_of_month - 1).end_of_month)
    subscription_payments.all(:conditions => ["created_at > '#{1.year.ago}'"]).collect(&:affiliate_amount).sum    
  end

end

