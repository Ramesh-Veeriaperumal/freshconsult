class Freshfone::Caller < ActiveRecord::Base
  self.table_name =  :freshfone_callers
  self.primary_key = :id
  include Search::ElasticSearchIndex
	
  belongs_to_account

  has_many :freshfone_calls, :class_name => "Freshfone::Call", :foreign_key => "caller_number_id"


  def to_indexed_json
    as_json({
            :root => "freshfone/caller",
            :tailored_json => true,
            :only => [ :number, :account_id ]
            }).to_json
  end
end