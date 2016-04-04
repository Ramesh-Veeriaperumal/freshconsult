class Freshfone::Caller < ActiveRecord::Base
  self.table_name =  :freshfone_callers
  self.primary_key = :id
  include Search::ElasticSearchIndex
	
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

  CALLER_TYPE_HASH.each_pair do |k, v|
    define_method("#{k}?") do
      caller_type == v
    end
  end

end