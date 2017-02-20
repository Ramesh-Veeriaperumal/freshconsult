class Admin::GamificationController < Admin::AdminController
  
  before_filter { |c| c.requires_this_feature :gamification }

  def index
    @scoreboard_ratings = current_account.scoreboard_ratings
    @scoreboard_levels = current_account.scoreboard_levels.find(:all, :order => "points ASC")
    @quests = all_scoper.all
  end
  
  def toggle
    if current_account.gamification_enable_enabled?
      current_account.features.gamification_enable.destroy
      current_account.revoke_feature(:gamification_enable)
    else
      current_account.features.gamification_enable.create
      current_account.add_feature(:gamification_enable)
    end
    current_account.reload
    render :nothing => true
  end

  def update_game    
    params[:scoreboard_ratings].each_value do |sb|
      scoreboard_rating = current_account.scoreboard_ratings.find(sb[:id])
      unless scoreboard_rating.update_attribute(:score, sb[:score])
        flash[:error] = t(:'admin.gamification.error_updated')
        return
      end
    end

    params[:scoreboard_levels].each_value do |sl|
      scoreboard_level = current_account.scoreboard_levels.find(sl[:id])
      unless scoreboard_level.update_attribute(:points, sl[:points])
        flash[:error] = t(:'admin.gamification.error_updated') #error?!
        return
      end
    end

    flash[:notice] = t(:'admin.gamification.successfully_updated')
    redirect_back_or_default '/admin/gamification'
  end

  def reset_arcade
    GamificationReset.perform_async()
    flash[:notice] = I18n.t('gamification.score_reset_successfull')
    redirect_to :back
  end

  protected
    def scoper
      current_account.quests
    end

    def all_scoper
      current_account.features?(:forums) ? current_account.all_quests :  current_account.all_quests.where("category != ?",Gamification::Quests::Constants::GAME_TYPE_KEYS_BY_TOKEN[:forum])
    end
end