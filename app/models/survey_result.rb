class SurveyResult < ActiveRecord::Base
  
  self.primary_key = :id

  include Va::Observer::Util
  include CustomSurvey::SurveyResult::PublisherMethods

  belongs_to_account
    
  has_one :survey_remark, :dependent => :destroy
  belongs_to :surveyable, :polymorphic => true
  
  belongs_to :agent,:conditions => {:deleted => false},:class_name => 'User', :foreign_key => :agent_id
  belongs_to :customer,:class_name => 'User', :foreign_key => :customer_id
  belongs_to :group,:class_name => 'Group', :foreign_key => :group_id
  belongs_to :survey, :class_name => 'CustomSurvey::Survey', :foreign_key => :survey_id

  after_create :update_ticket_rating
  before_create :update_observer_events
  after_commit :filter_observer_events, on: :create, :if => :user_present?
  
  concerned_with :presenter
  publishable

  def add_feedback(feedback)
    note = surveyable.notes.build({
      :user_id => customer_id,
      :note_body_attributes => {:body => Helpdesk::HTMLSanitizer.plain(feedback)},
      :source => Account.current.helpdesk_sources.note_source_keys_by_token["feedback"],
      :incoming => true,
      :private => false
    })
    
    note.account_id = account_id
    note.save_note

    remark = build_survey_remark
    remark.feedback = note
    remark.save
         
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

    Account.current.survey.safe_send(txt)
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

  scope :agent, -> (conditional_params) { 
    where(conditional_params).
    select("users.id as id, users.name as name,survey_results.rating as rating,users.job_title as title,count(*) as total").
    group("survey_results.agent_id, survey_results.rating").
    order(:name)
  }

  scope :group_scope, -> (conditional_params) { 
    where(conditional_params).
    select("group_id as id,groups.name as name,survey_results.rating as rating,groups.description as title,count(*) as total").
    group("survey_results.group_id, survey_results.rating").
    order(:name)
  }

  scope :portal, -> (conditional_params) { 
    where(conditional_params).
    select("account_id as id,accounts.name as name,survey_results.rating as rating,accounts.full_domain as title,count(*) as total").
    group("survey_results.account_id, survey_results.rating").
    joins(:account)
    order(:name)
  }

  scope :remarks, -> (conditional_params) { 
    where(conditional_params).
    includes(:survey_remark).
    order(survey_results.created_at DESC)
  }             
                  
  def as_json(options={})
    options[:except] = [:account_id]
    super options
  end

  def self.survey_filter(survey_result_filter)
      {
        default: {
          conditions: ['created_at > ?', created_in_last_month ]
        },
        created_since: {
          conditions: ['created_at >= ?', survey_result_filter.created_since.try(:to_time).try(:utc) ]
        },
        user_id: {
          conditions: { customer_id: survey_result_filter.user_id }
        }
      }
  end

  def self.created_in_last_month
    # created in last month filter takes up user time zone info also into account.
    in_user_time_zone { Time.zone.now.beginning_of_day.ago(1.month).utc }
  end

  def self.in_user_time_zone(&block)
    old_zone = Time.zone
    TimeZone.set_time_zone
    yield
  ensure
    Time.zone = old_zone
  end

  private                                                   

    def update_ticket_rating
      return unless surveyable.is_a? Helpdesk::Ticket

      surveyable.st_survey_rating= rating
      surveyable.survey_rating_updated_at= created_at
      surveyable.save
    end
    
    # VA - Observer Rule 
    def update_observer_events
      return unless surveyable.instance_of? Helpdesk::Ticket
      @model_changes = { :customer_feedback => rating }
    end
end
