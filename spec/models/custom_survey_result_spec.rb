require 'spec_helper'

describe CustomSurvey::SurveyResult do 
  before(:all) do
    setup_data
    @new_agent = add_agent_to_account(@account, {:name => "testing", :email => Faker::Internet.email,
                                                 :active => 1, :role => 4,
                                                 :group_id => @group.id})


    @new_ticket = create_ticket({:status => 2}, @group)
    @another_ticket = create_ticket({:status => 2}, @group)
    @user = User.find_by_account_id(@account.id)
  end

  before(:each) do
    @ticket.responder_id = nil
    @ticket.save!
    @new_ticket.responder_id = nil
    @new_ticket.save!
    @note = @ticket.notes.build(
            :user_id => @user.id,
            :note_body_attributes => {
              :body => "body two",
              :body_html => "<div>body two</div>"
          },
          :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["feedback"],
          :incoming => true,
          :private => false
          )
    @note.save_note
  end


  def setup_data
    @group = create_group(@account,{:ticket_assign_type => 1, :name =>  "dummy group"})
    @group.ticket_assign_type = 1
    @group.save!

    @agent = add_agent_to_account(@account, {:name => "testing2", :email => Faker::Internet.email,
                                             :active => 1, :role => 1
                                            })
    @agent.available = 1
    @agent.save!

    ag_grp = AgentGroup.new(:user_id => @agent.user_id , :account_id =>  @account.id, :group_id => @group.id)
    ag_grp.save!

    @ticket = create_ticket({:status => 2}, @group)
    @ticket.group_id = @group.id
    @ticket.save!
  end

  it "should add survey remarks" do 
  	remark = @account.survey_remarks.create({
      :account_id => @account.id,
      :note_id => @note.id
    })
    remark.id.should_not eql nil
  end

  it "should include survey for report" do 
      survey = @account.custom_surveys.first
      survey_handle= CustomSurvey::SurveyHandle.create_handle_for_notification(@ticket,
                     EmailNotification::PREVIEW_EMAIL_VERIFICATION,survey.id,true,false)
      test_result = survey_handle.create_survey_result(CustomSurvey::Survey::EXTREMELY_HAPPY)
      reports = {:survey_id => survey.id , :rating => {}, :total => 0}
      survey_reports = survey.survey_results(:survey_id=>survey.id , :start_date=>survey.created_at , :end_date =>survey.updated_at)
      survey_reports.each do |report|
          reports[:rating][report[:rating].to_i] = report[:total].to_i
          reports[:total] += report[:total].to_i
      end
      reports[:rating].should_not eql nil
      reports[:total].should_not eql nil
  end

  it "should include group wise report" do
      group_name= []
      survey = @account.custom_surveys.first
      groups = @account.groups.find(:all)
      groups.each do |group|
        survey_handle= CustomSurvey::SurveyHandle.create_handle_for_notification(@ticket,
                      EmailNotification::PREVIEW_EMAIL_VERIFICATION,survey.id,true,false)
        @test_result = survey_handle.create_survey_result(CustomSurvey::Survey::NEUTRAL)
        group_name.push(group.name)
      end
      
      survey_reports = @ticket.survey_results.find(:all , :select => 'id,survey_id')
      group_report = Hash.new
      survey_reports.each_with_index do |report,index|
        key = report[:id]
        if group_report[key].blank?
          group_report[key] = {:id=>report[:id], :name => group_name[index], :total => 0, :rating => {}}
        end
        group_report[key][:rating][report[:rating].to_i] = report[:total].to_i
        group_report[key][:total] += report[:total].to_i

        #assert statements
        group_wise_report = group_report[key]
        group_report[key].should_not eql nil
        group_wise_report[:id].should_not eql nil
        group_wise_report[:rating].should_not eql nil
        group_wise_report[:total].should_not eql nil

      end
  end

  it "should include agent wise report" do
      agent_name= []
      survey = @account.custom_surveys.first
      agents = @account.agents.find(:all)
      agents.each do |agent|
        survey_handle= CustomSurvey::SurveyHandle.create_handle_for_notification(@ticket,
                       EmailNotification::PREVIEW_EMAIL_VERIFICATION,survey.id,true,false)
        @test_result = survey_handle.create_survey_result(CustomSurvey::Survey::EXTREMELY_UNHAPPY)
        agent_name.push(agent.user.name)
      end
      
      survey_reports = @ticket.survey_results.find(:all , :select => 'id,survey_id')
      agent_report = Hash.new
      survey_reports.each_with_index do |report,index|
        key = report[:id]
        if agent_report[key].blank?
          agent_report[key] = {:id=>report[:id], :name => agent_name[index], :total => 0, :rating => {}}
        end
        agent_report[key][:rating][report[:rating].to_i] = report[:total].to_i
        agent_report[key][:total] += report[:total].to_i

        #assert statements
        agent_wise_report = agent_report[key]
        agent_report[key].should_not eql nil
        agent_wise_report[:id].should_not eql nil
        agent_wise_report[:rating].should_not eql nil
        agent_wise_report[:total].should_not eql nil
      end
  end
end