class Freshfone::Caller < ActiveRecord::Base

	include Search::ElasticSearchIndex
	
  set_table_name :freshfone_callers
  belongs_to_account

  has_many :freshfone_calls, :class_name => "Freshfone::Call", :foreign_key => "caller_number_id"

  def to_indexed_json
    to_json({
            :root => "freshfone/caller",
            :tailored_json => true,
            :only => [ :number, :account_id ]
            })
  end
end