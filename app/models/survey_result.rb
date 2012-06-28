class SurveyResult < ActiveRecord::Base

  belongs_to_account
    
  has_one :survey_remark, :dependent => :destroy
  belongs_to :surveyable, :polymorphic => true
  
  has_one :user,:conditions => {:deleted => false}, :foreign_key => :customer_id
  belongs_to :agent,:conditions => {:deleted => false},:class_name => 'User', :foreign_key => :agent_id
  belongs_to :customer,:conditions => {:deleted => false},:class_name => 'User', :foreign_key => :customer_id
  belongs_to :group,:class_name => 'Group', :foreign_key => :group_id
  
  def add_feedback(feedback)
    note = surveyable.notes.build({
      :user_id => customer_id,
      :body => feedback,
      :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["feedback"],
      :incoming => true,
      :private => false
    })
    
    note.account_id = account_id
    note.save
    
    create_survey_remark({
      :account_id => account_id,
      :note_id => note.id
    })
    
    # add_support_score
  end
  
  def happy?
    (rating == Survey::HAPPY)
  end

  def unhappy?
    (rating == Survey::UNHAPPY)
  end
  
  private
  
  def self.generate_reports_list(survey_reports,category)
    
  agents_report = Hash.new

  rating = Hash.new

    survey_reports.each do |report|
      
        key = report[:id]

    if agents_report[key].blank?
      agents_report[key] = {:entity_id=>report[:id], :category => category, :name => report[:name], :title => (report[:title] || ""), :happy => 0, :unhappy => 0, :neutral => 0, :total => 0,:rating => {"happy"=>0,"neutral"=>0,"unhappy"=>0}}
    end   


    if report[:rating].to_i == Survey::HAPPY
      agents_report[key][:happy] = report[:total].to_i
      agents_report[key][:rating]["happy"] = report[:total].to_i      
    elsif report[:rating].to_i == Survey::UNHAPPY
      agents_report[key][:unhappy] = report[:total].to_i
      agents_report[key][:rating]["unhappy"] = report[:total].to_i
    else
      agents_report[key][:neutral] = report[:total].to_i
      agents_report[key][:rating]["neutral"] = report[:total].to_i
    end

    agents_report[key][:total] += report[:total].to_i

  end

  agents_report

  end
  
    def add_support_score
      SupportScore.happy_customer(surveyable) if happy?
      SupportScore.unhappy_customer(surveyable) if unhappy?
    end
    
end