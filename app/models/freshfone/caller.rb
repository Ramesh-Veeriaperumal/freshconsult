class Freshfone::Caller < ActiveRecord::Base
  self.table_name =  :freshfone_callers
  self.primary_key = :id
  include Search::ElasticSearchIndex
  include Freshfone::CallerLookup

  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher
	
  belongs_to_account

  has_many :freshfone_calls, :class_name => "Freshfone::Call", :foreign_key => "caller_number_id"

  CALLER_TYPE = [
    [:normal, 'normal', 0],
    [:blocked, 'blocked', 1]
  ]

  CALLER_TYPE_HASH = Hash[*CALLER_TYPE.map{|i|[i[0],i[2]]}.flatten]
  
  scope :blocked_callers, :conditions => ['caller_type = ?', CALLER_TYPE_HASH[:blocked]]
  def to_indexed_json
    as_json({
            :root => "freshfone/caller",
            :tailored_json => true,
            :only => [ :number, :account_id ]
            }).to_json
  end
  
  def to_esv2_json
    as_json({
      root: false,
      tailored_json: true,
      only: [ :account_id, :number ]
    }).to_json
  end

  CALLER_TYPE_HASH.each_pair do |k, v|
    define_method("#{k}?") do
      caller_type == v
    end
  end

  def name_or_location
    strange_number_name || location
  end

  def location
    city_name || state_name || coded_country.name
  end

  def city_name
    city if city.present?
  end

  def state_name
    return if state.blank?
    return state if country != 'US'
    full_state_name
  end

  def full_state_name
    coded_state = coded_country.subregions.coded(state)
    coded_state.name if coded_state.present?
  end

  def coded_country
    Carmen::Country.coded(country)
  end

  def strange_number_name
    caller_lookup(number) if strange_number?(number)
  end
end