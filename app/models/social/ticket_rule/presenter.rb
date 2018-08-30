class Social::TicketRule < ActiveRecord::Base
  include RepresentationHelper
  acts_as_api
  api_accessible :central_publish do |t|
    t.add :account_id
    t.add proc { |x| x.utc_format(x.created_at) }, as: :created_at
    t.add proc { |x| x.utc_format(x.updated_at) }, as: :updated_at
    t.add proc { |x| x.type }, as: :type
    t.add proc { |x| x.action_data.except(:capture_dm_as_ticket) }, as: :action
    t.add :stream_id
    t.add :id
  end
end