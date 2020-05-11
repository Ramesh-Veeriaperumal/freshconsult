class Moderatorship < ActiveRecord::Base
  self.primary_key = :id
  belongs_to :forum
  belongs_to :user
  before_create { |r| where(['forum_id = ? and user_id = ?', r.forum_id, r.user_id]).count(:id).zero? }
end
