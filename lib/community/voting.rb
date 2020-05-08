module Community::Voting

  def fetch_vote
    @vote = vote_parent.votes.where(user_id: current_user.id).first_or_initialize
  end

  def toggle_vote
    @vote.new_record? ? create_vote : destroy_vote
    vote_parent.reload
  end

  def create_vote
    @vote.vote = true
    @vote.save
  end

  def destroy_vote
    @vote.destroy unless @vote.new_record?
  end
  
end