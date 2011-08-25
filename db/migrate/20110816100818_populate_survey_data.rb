class PopulateSurveyData < ActiveRecord::Migration
  def self.up
    Account.all.each do |account|
      account.features.survey_links.create
      account.features.scoreboard.create
      
      survey = account.build_survey(
        :link_text => 'Please take a minute to rate your customer support experience',
        :send_while => Survey::RESOLVED_NOTIFICATION )
      survey.save!
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
