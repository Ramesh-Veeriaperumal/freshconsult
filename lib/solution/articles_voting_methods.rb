module Solution::ArticlesVotingMethods

  def thumbs_up
    success = update_votes(:thumbs_up, 1)
    respond_to do |format|
      format.xml { head :ok }
      format.json { render :json => {:success => success} }
      format.any(:html, :js, :atom, :nmobile, :widget) {
        # Rendering the feedback form for the user... to get his comments
        render :text => I18n.t('solution.articles.article_useful')
      }
    end
  end

  def thumbs_down
    # Voting down the article
    success = update_votes(:thumbs_down, 0)

    # Getting a new object for submitting the feeback for the article
    @ticket = Helpdesk::Ticket.new
    respond_to do |format|
      format.xml { head :ok }
      format.json { render :json => {:success => success} }
      format.any(:html, :js, :atom, :nmobile, :widget) {
        # Rendering the feedback form for the user... to get his comments
        render :partial => "/support/solutions/articles/feedback_form"
      }
    end
  end

  def update_votes(incr_attr, vote)
    return false if @portal && current_user && current_user.agent?
    return @article.send("#{incr_attr}!") unless current_user

    @vote.vote = vote
    if @vote.new_record?
      @article.send("#{incr_attr}!")
    elsif @vote.vote_changed?
      @article.send("toggle_#{incr_attr}!")
    end
    @vote.save
  end

  def load_vote
    @vote = @article.votes.find_or_initialize_by_user_id(current_user.id) if current_user
  end
end
