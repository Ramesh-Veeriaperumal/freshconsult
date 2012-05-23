class ConversionMetric < ActiveRecord::Base
  belongs_to :account
  has_one :subscription, :through => :account
  serialize :session_json, Hash
  before_create :update_referrer_type, :update_keywords
  
  REFERRER_CATEGORIES = [
      [:gmp,     "Google Market Place",    1],
      [:gl,      "G-App Login",            2],
      [:ga,      "Google Adwords",         3],
      [:gad,     "Google Ads Display",     4],
      [:go,      "Google Organic",         5],
      [:gr,      "Google Reader",          6],
      [:direct,  "Direct",                 7],
      [:others,  "Others",                 8],
      [:total,   "Total",                  0 ]
    ]
  
  CATEGORIES = Hash[*REFERRER_CATEGORIES.map { |i| [i[0], i[1]] }.flatten]
  
  REFERRER_TYPE = Hash[*REFERRER_CATEGORIES.map { |i| [i[2], i[0]] }.flatten]
  
  def self.get_category_string(code)
    return CATEGORIES[code]
  end
  
  def parse_landing_url(url)
      get_path_string(url).to_str.capitalize
  end    
    
  def update_referrer_type(*url)
      url = self[:first_referrer] if url.blank?
      self[:referrer_type] = get_referrer_type(url,true)
  end
  
  def get_referrer_code(type)      
      REFERRER_TYPE[type]
  end
  
  def get_referrer_type(url,is_first)
    if is_google_market_place?(url,is_first)
          return 1
    elsif is_google_accounts?(url,is_first)
          return 2
    elsif is_google_adwords?(url)
          return 3
    elsif is_google_ads_display?(url)
          return 4
    elsif is_google_reader?(url,is_first)
              return 5      
    elsif is_google_organic?(url,is_first)
          return 6
    elsif is_utm?(url)          
          return 8
    elsif is_direct?(url)
          return 7
    end
    return 8
  end
  
  def get_referrer_string(url,is_first)
      ref_string = REFERRER_TYPE[get_referrer_type(url,is_first)]
      if (ref_id == 8)
        path = get_path_string(url)
        ref_string =  ref_string + " <br> ( " + path  +" )"
      end
      return ref_string
  end
  
  #fetches the category based on the url
  def get_referrer_category(url,is_first)
    
    if is_google_market_place?(url,is_first)
          return CATEGORIES[:gmp]
    elsif is_google_accounts?(url,is_first)
          return CATEGORIES[:gl]
    elsif is_google_adwords?(url)
          return CATEGORIES[:ga]
    elsif is_google_ads_display?(url)
          return CATEGORIES[:gad]
    elsif is_utm?(self.first_landing_url)
          return get_utm_source
    elsif is_google_reader?(url,is_first)
          return CATEGORIES[:gr]
    elsif is_google_organic?(url,is_first)
          return CATEGORIES[:go]
    elsif is_direct?(url)
          cat = CATEGORIES[:direct]
          path = get_path_string(url)
          cat =  cat + " <br> ( " + path  +" )"
          return cat
    end
    
    host = split_url(url)
    host = (host[4].blank?) ? host : host[4]
    return host
    
  end
  
  def get_amount
      self.subscription.amount
  end
  
  def trim_domain(domain)
      domain.gsub(/.freshdesk.com/,"")
  end
  
  def get_path_string(url)
      path = get_path(url).gsub(/\//," ")
      path = !(path.blank?) ? path : "Home"
      return path
  end
  
  def get_utm_source
      utm_info = (Rack::Utils.parse_nested_query URI(self.first_landing_url).query)
      return utm_info["utm_source"]
  end
  
  def trim_url(keyword)
      (!keyword.blank? && is_url?(keyword)) ? get_domain(keyword) : keyword
  end
  
  def get_host(url)
    host = split_url(url)
    return host if host[4].blank?
    return host[4]
  end
  
  def is_url?(url)

      return !(get_domain(url).blank?)

  end
  
  def get_css_class
      if is_trial_customer?
         return "trial"
      elsif is_paid_customer?
         return "paid"
      else return "free"
      end   
         
  end
  
  # To check whether the referrer url is direct
  def is_direct?(url)
    !(/freshdesk.com/.match(get_domain(url)).blank?)
  end
  
  # To check whether the referrer url is from Google Ads Display
  def is_google_ads_display?(url)
    !(/doubleclick.net/.match(get_domain(url)).blank?)
  end
  
  # To check whether the referrer url is from Google Ad Words
  def is_google_adwords?(url)
    is_direct?(url) && !(/gclid/.match(url).blank?)
  end
  
  # To check whether the signup made via google accounts
  def is_google_accounts?(url,is_first)
    !(/accounts.google.com/.match(get_domain(url)).blank?)
  end
  
  # To check whether the signup made via google market place  
  def is_google_market_place?(url,is_first)
    flu = is_first ? self.first_landing_url : self.landing_url
    prod_id_regex = %r"productListingId=9356\+11308236248743392394"
    return (!(prod_id_regex.match(url).blank?) or !(prod_id_regex.match(flu).blank?))
  end
  
  # To check whether the referrer is google organic search
  def is_google_organic?(url,is_first)
    !is_google_accounts?(url,is_first) && !(/google/.match(get_domain(url)).blank?)
  end
  
  # To check whether the referrer is google organic search
  def is_google_reader?(url,is_first)    
      is_google_organic?(url,is_first) && !(/reader/.match(get_path(url)).blank?)            
  end
  
  def get_ads_keywords(url)
      if (( self.keywords.blank? || self.keywords.eql?("None") ))
        params = get_params(url)
        if (!params.blank? && /url/.match(params))
          params = CGI::unescape(params).scan(/((http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.[\w-]*)?)/ix)
          return params[0][0] unless (params.blank? && params[0].blank?)
        end
      end
  end
  
  def init_keywords
      update_keywords(self[:first_referrer])
  end
  
  def update_keywords(*url)
    url = self[:first_referrer] if url.blank?
    return if url.blank?
    self[:keywords] = get_ads_keywords(url) if is_google_ads_display?(url)
    url_split = split_url(url)
     if is_utm?(url)
       utm_info = (Rack::Utils.parse_nested_query URI(self.first_landing_url).query)
       self[:keywords] = utm_info["utm_term"] unless (utm_info["utm_term"].blank?)
       self[:keywords] = utm_info["utm_campaign"] unless (!utm_info["utm_term"].blank? && utm_info["utm_campaign"].blank?)
     end
     unless url_split[9].blank?
          keyword = CGI::unescape(url_split[9]).split('/')
          self[:keywords] = keyword[keyword.length-1]
     end
  end
  
  # To check whether the signup made via utm sources
  def is_utm?(url)
    !(/utm_source/.match(url).blank?)
  end
  
  # To check whether the customer is free or paid
  def is_paid_customer?
      self.subscription.state=='active' && self.subscription.amount > 0
  end  
  
  # To check whether the customer is free or paid
  def is_trial_customer?
      self.subscription.state=='trial'
  end    
  
  def url_regex
    %r"^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?$"
  end
  
  # URL domain splitter 1.scheme with colon, 2.scheme, 3.domain with preceding //, 4.domain,
   # 5.path, 6.?params, 7.params
   def split_url(url)       
       return url.match(url_regex)
   end
   
   def get_domain(url)
       split_url(url)[4]     
   end
   
   def get_path(url)
        split_url(url)[5]
   end
    
   def get_params(url)
         split_url(url)[7]
   end
   
end