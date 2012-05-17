class SurveyResult < ActiveRecord::Base
	
  belongs_to_account
    
  has_one :survey_remark, :dependent => :destroy
  belongs_to :surveyable, :polymorphic => true
  
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
  
  def self.fetch_agent_report(account_id,condition)  	
  	sql_query = %(select users.id, users.name, job_title as title, rating,count(*) as total from agents 
  				  inner join users on users.id=agents.user_id inner join survey_results on survey_results.agent_id=users.id 
  				  where users.account_id=#{account_id} )
  		
  	sql_query += "and agents.user_id=#{condition[:entity_id]} " unless condition[:entity_id].blank?
  	sql_query += "and survey_results.created_at between '#{condition[:start_date]}' and '#{condition[:end_date]}' "
  	sql_query += "group by agents.id,rating"
	survey_reports = Survey.find_by_sql(sql_query)
	generate_reports_list(survey_reports,"agent")
  end
 
  def self.fetch_group_report(account_id,condition)
  	sql_query = %(select agent_groups.group_id as id, groups.name, groups.description as title, rating,count(*) as total 
  				  from agent_groups inner join groups on groups.id=agent_groups.group_id
  				  inner join survey_results on survey_results.agent_id=agent_groups.user_id
  				  where groups.account_id=#{account_id} )
  		
  	sql_query += "and agent_groups.group_id=#{condition[:entity_id]} " unless condition[:entity_id].blank?
  	sql_query += "and survey_results.created_at between '#{condition[:start_date]}' and '#{condition[:end_date]}' "
  	sql_query += "group by agent_groups.group_id,rating"
	survey_reports = Survey.find_by_sql(sql_query)
	generate_reports_list(survey_reports,"group")
  end
  
  def self.fetch_company_report(account_id,condition)
  	sql_query = %(select accounts.id, accounts.name, full_domain as title, rating,count(*) as total from accounts 
  				  inner join survey_results on survey_results.account_id=accounts.id 
  				  where accounts.id=#{account_id} and survey_results.created_at between '#{condition[:start_date]}' and '#{condition[:end_date]}' group by rating)	
	survey_reports = Survey.find_by_sql(sql_query)
	generate_reports_list(survey_reports,"account")
  end
  
  def self.fetch_agent_report_details(account_id,condition)
  	sql_query = %(select survey_results.customer_id as customer_id, users.name,survey_remarks.created_at,body,rating from survey_results 
  				  inner join survey_remarks on survey_remarks.`survey_result_id`=survey_results.id inner join 
  				  helpdesk_notes on survey_remarks.note_id=helpdesk_notes.id inner join users on 
  				  users.id=survey_results.customer_id where survey_results.account_id=#{account_id})
  				  
  	condition.each do |key,val|
  		sql_query += " and survey_results.rating=#{val}" if key == :rating
  		sql_query += " and survey_results.agent_id=#{val}" if key == :entity_id
  	end
  	
	Survey.find_by_sql(sql_query)
	
  end
  
  def self.fetch_group_report_details(account_id,condition)
  	sql_query = %(select survey_results.customer_id as customer_id, users.name,survey_remarks.created_at,body,rating,agent_groups.user_id,agent_groups.group_id from agent_groups
				  inner join survey_results on survey_results.agent_id=agent_groups.user_id
  				  inner join survey_remarks on survey_remarks.`survey_result_id`=survey_results.id inner join 
  				  helpdesk_notes on survey_remarks.note_id=helpdesk_notes.id inner join users on 
  				  users.id=survey_results.customer_id where survey_results.account_id=#{account_id})
  	
  	condition.each do |key,val|
  		sql_query += " and survey_results.rating=#{val}" if key == :rating
  		sql_query += " and agent_groups.group_id=#{val}" if key == :entity_id
  	end
  	
	Survey.find_by_sql(sql_query)
	
  end
  
  def self.fetch_company_report_details(account_id,condition)
  	sql_query = %(select survey_results.customer_id as customer_id, users.name,survey_remarks.created_at,body,rating from survey_results 
  				  inner join survey_remarks on survey_remarks.`survey_result_id`=survey_results.id inner join 
  				  helpdesk_notes on survey_remarks.note_id=helpdesk_notes.id inner join users on 
  				  users.id=survey_results.customer_id where survey_results.account_id=#{account_id})
  				  
  	condition.each do |key,val|
  		sql_query += " and survey_results.rating=#{val}" if key == :rating  		
  	end
  	
	Survey.find_by_sql(sql_query)
	
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
