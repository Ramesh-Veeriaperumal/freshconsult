class SurveyResult < ActiveRecord::Base

  include Gamification::GamificationUtil  
  include Va::Observer::Util

  belongs_to_account
    
  has_one :survey_remark, :dependent => :destroy
  belongs_to :surveyable, :polymorphic => true
  
  belongs_to :agent,:conditions => {:deleted => false},:class_name => 'User', :foreign_key => :agent_id
  belongs_to :customer,:class_name => 'User', :foreign_key => :customer_id
  belongs_to :group,:class_name => 'Group', :foreign_key => :group_id

  after_create :update_ticket_rating, :add_support_score
  after_commit_on_create :process_ticket_quests_on_feedback
  before_create :update_observer_events
  after_commit_on_create :filter_observer_events, :if => :user_present?
  
  def add_feedback(feedback)
    note = surveyable.notes.build({
      :user_id => customer_id,
      :note_body_attributes => {:body => feedback},
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
         
  end
  
  def happy?
    (rating == Survey::HAPPY)
  end

  def unhappy?
    (rating == Survey::UNHAPPY)
  end
  
  def get_small_img_class
        if happy?
           return "happy-smily-small"
        elsif unhappy?
           return "unhappy-smily-small"
        else
           return "neutral-smily-small"
        end
  end

  def text
    if happy?
      txt = 'happy_text'
    elsif unhappy?
      txt = 'unhappy_text'
    else
      txt = 'neutral_text'
    end

    Account.current.survey.send(txt)
  end

  def self.generate_reports_list(survey_reports,category,sort_by)
    
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

  if sort_by == "happy"
    agents_report.sort_by{|key,value| value[:happy]}.reverse 
  elsif  sort_by == "unhappy"
    agents_report.sort_by{|key,value| value[:unhappy]}.reverse
  elsif  sort_by == "neutral"
    agents_report.sort_by{|key,value| value[:neutral]}.reverse
   elsif  sort_by == "total"
     agents_report.sort_by{|key,value| value[:total]}.reverse
    else
      agents_report.sort_by{|key,value| value[:name]}
    end  

  end

  named_scope :agent , lambda { |conditional_params| { :joins => :agent,
                                                     :select => "users.id as id,users.name as name,survey_results.rating as rating,users.job_title as title,count(*) as total",
                                                     :group => "survey_results.agent_id,survey_results.rating", 
                                                     :conditions => conditional_params,
                                                     :order => :name
                                                   }}
  
  named_scope :group , lambda { |conditional_params| { :joins => :group,
                                                     :select => "group_id as id,groups.name as name,survey_results.rating as rating,groups.description as title,count(*) as total",
                                                     :group => "survey_results.group_id,survey_results.rating",
                                                     :conditions => conditional_params,                                                     
                                                     :order => :name
                                                   }}

  named_scope :portal , lambda { |conditional_params| { :joins => :account,                    
                                                      :select => "account_id as id,accounts.name as name,survey_results.rating as rating,accounts.full_domain as title,count(*) as total",                
                                                      :group => "survey_results.account_id,survey_results.rating",
                                                      :conditions => conditional_params,                                                     
                                                      :order => :name
                                                   }}

  named_scope :remarks , lambda { |conditional_params| { 
                                                      :include => :survey_remark,
                                                      :conditions => conditional_params,
                                                      :order => "survey_results.created_at DESC"
                                                   }}                                                   

                                                     
  private                                                   

    def add_support_score
      return unless gamification_feature?(surveyable.account)
      SupportScore.add_happy_customer(surveyable) if happy?
      SupportScore.add_unhappy_customer(surveyable) if unhappy?
    end

    def update_ticket_rating
      return unless surveyable.is_a? Helpdesk::Ticket

      surveyable.st_survey_rating= rating
      surveyable.survey_rating_updated_at= created_at
      surveyable.save
    end
    
    def process_ticket_quests_on_feedback
      Resque.enqueue(Gamification::Quests::ProcessTicketQuests, { :id => surveyable_id, 
                :account_id => account_id }) if gamification_feature?(surveyable.account)
    end

    # VA - Observer Rule 
    def update_observer_events
      return unless surveyable.instance_of? Helpdesk::Ticket
      @model_changes = { :customer_feedback => rating }
    end

end