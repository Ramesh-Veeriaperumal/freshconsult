class Support::SurveysController < ApplicationController
  def new
    @survey_handle = current_account.survey_handles.find_by_id_token(params[:survey_code])
    @rating = params[:rating]
    unless @survey_handle
      flash[:warning] = "Invalid survey code, you might have already given the feedback"
    end
    
    #To do - Populate the survey_scores and update the score_id in handle model
  end
  
  def create
    puts "CREATE******** SURVEY CODE issss #{params[:survey_code]}"
    puts "RATING is #{params[:rating]}"
    
    #To do. 1. Store the feedback in notes and remarks table.
    #2. Clear the handle record.
    
    flash[:notice] = "Thanks for the feedback" #change the text
    redirect_to root_path
  end

end
