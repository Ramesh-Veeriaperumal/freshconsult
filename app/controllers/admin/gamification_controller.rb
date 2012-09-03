class Admin::GamificationController < Admin::AdminController
  
  before_filter { |c| c.requires_feature :scoreboard }

  def index
    @account = current_account
    @scoreboard_ratings = current_account.scoreboard_ratings
    @scoreboard_levels = current_account.scoreboard_level
    @inactive_quests = all_scoper.disabled
    @quests = scoper.find(:all)
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
      scoreboard_ratings = current_account.scoreboard_ratings.find(sb[:id])
      scoreboard_ratings[:score] = sb[:score]
      if scoreboard_ratings.save
        flash[:notice] = t(:'admin.gamification.successfully_updated')
      else
        flash[:notice] = t(:'admin.gamification.error_updated') #error?!
      end   
    end

    scoreboard_level = current_account.scoreboard_level
    params[:scoreboard_level].each_with_index do |sl , index|
      puts "scoreboard_level *** sl is #{sl.inspect}"
      puts "scoreboard_level *** index is #{index}"
      puts scoreboard_level.levels_data[index][2] = sl[1][:value]
    end

    if scoreboard_level.save
      flash[:notice] = t(:'admin.scoreboard.successfully_updated')
    else
      flash[:notice] = t(:'admin.scoreboard.error_updated')
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