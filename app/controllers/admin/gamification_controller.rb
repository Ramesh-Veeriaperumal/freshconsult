class Admin::GamificationController < Admin::AdminController
  
  before_filter { |c| c.requires_feature :gamification }

  def index
    @scoreboard_ratings = current_account.scoreboard_ratings
    @scoreboard_levels = current_account.scoreboard_levels.find(:all, :order => "points ASC")
    @quests = all_scoper.all
  end
  
  def toggle
    if feature?(:gamification_enable)
      current_account.features.gamification_enable.destroy
    else
      current_account.features.gamification_enable.create
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

    Resque::enqueue(CRM::Totango::SendUserAction,{ :account_id => current_account.id, 
                                                    :email => current_user.email, 
                                                    :activity => totango_activity(:arcade) })
    flash[:notice] = t(:'admin.gamification.successfully_updated')
    redirect_back_or_default '/admin/gamification'
  end

  protected
    def scoper
      current_account.quests
    end

    def all_scoper
      current_account.all_quests
    end
end