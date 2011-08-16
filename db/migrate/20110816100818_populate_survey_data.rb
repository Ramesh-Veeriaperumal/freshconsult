class PopulateSurveyData < ActiveRecord::Migration
  def self.up
    Account.all.each do |account|
      account.features.survey_links.create
      
      survey = account.build_survey(
        :link_text => 'Please take a minute to rate your customer support experience',
        :send_while => Survey::RESOLVED_NOTIFICATION )
      survey.save!
      
      survey.survey_points.create(
        [
          { :resolution_speed => SurveyPoint::FAST_RESOLUTION, :customer_mood => 
            SurveyPoint::HAPPY, :score => 5 },
          { :resolution_speed => SurveyPoint::FAST_RESOLUTION, :customer_mood => 
            SurveyPoint::NEUTRAL, :score => 3 },
          { :resolution_speed => SurveyPoint::FAST_RESOLUTION, :customer_mood => 
            SurveyPoint::UNHAPPY, :score => 0 },
          { :resolution_speed => SurveyPoint::ON_TIME_RESOLUTION, :customer_mood => 
            SurveyPoint::HAPPY, :score => 3 },
          { :resolution_speed => SurveyPoint::ON_TIME_RESOLUTION, :customer_mood => 
            SurveyPoint::NEUTRAL, :score => 1 },
          { :resolution_speed => SurveyPoint::ON_TIME_RESOLUTION, :customer_mood => 
            SurveyPoint::UNHAPPY, :score => -1 },
          { :resolution_speed => SurveyPoint::LATE_RESOLUTION, :customer_mood => 
            SurveyPoint::HAPPY, :score => 1 },
          { :resolution_speed => SurveyPoint::LATE_RESOLUTION, :customer_mood => 
            SurveyPoint::NEUTRAL, :score => 0 },
          { :resolution_speed => SurveyPoint::LATE_RESOLUTION, :customer_mood => 
            SurveyPoint::UNHAPPY, :score => -3 },
          { :resolution_speed => SurveyPoint::REGULAR_EMAIL, :customer_mood => 
            SurveyPoint::HAPPY, :score => 5 },
          { :resolution_speed => SurveyPoint::REGULAR_EMAIL, :customer_mood => 
            SurveyPoint::NEUTRAL, :score => 3 },
          { :resolution_speed => SurveyPoint::REGULAR_EMAIL, :customer_mood => 
            SurveyPoint::UNHAPPY, :score => 0 }
        ])
    end
    
    plans = SubscriptionPlan.find(:all, :conditions => ["name in (?, ?)", 'Pro', 'Premium'])
    Subscription.find(:all, :include => :account, 
      :conditions => { :subscription_plan_id => plans.collect(&:id) }).each do |subscrn|
      subscrn.account.features.surveys.create
    end
  end

  def self.down
  end
end
