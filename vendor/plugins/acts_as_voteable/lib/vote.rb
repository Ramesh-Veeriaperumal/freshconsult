class Vote < ActiveRecord::Base

  # NOTE: Votes belong to a user
  belongs_to :user

  belongs_to :voteable, :polymorphic => true

  after_create :update_user_votes_count
  after_destroy :update_user_votes_count

  def self.find_votes_cast_by_user(user)
    find(:all,
      :conditions => ["user_id = ?", user.id],
      :order => "created_at DESC"
    )
  end

  def update_user_votes_count
  	return unless voteable.is_a? Topic
  	voteable.user_votes = voteable.votes_count
  	voteable.save
  end

end