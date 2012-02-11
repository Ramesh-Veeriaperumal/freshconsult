class ConversionMetric < ActiveRecord::Base
  belongs_to :account
  serialize :session_json, Hash
end
