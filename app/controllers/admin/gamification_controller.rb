class Admin::GamificationController < Admin::AdminController
  
  before_filter { |c| c.requires_feature :scoreboard }

  def index
    @scoreboard_ratings = current_account.scoreboard_ratings
    @scoreboard_levels = current_account.scoreboard_levels.find(:all, :order => "points ASC")
    @inactive_quests = all_scoper.disabled
    @quests = scoper.all
  end
  
  def enable    
   current_account.features.scoreboard_enable.create     
   current_account.reload
  end
  
  def disable
   current_account.features.scoreboard_enable.destroy
   current_account.reload
  end

  def update
    
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
  end

  def active_quests
    @active_quest = scoper.find(:all)
    respond_to do |format|
      format.json { render :json => @active_quest}
    end
  end

  protected
    def scoper
      current_account.quests
    end

    def all_scoper
      current_account.all_quests
    end
end