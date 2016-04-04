require 'spec_helper'

describe SurveyResult do 
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
    #build survey notes
    note = @ticket.notes.build(
          :user_id => @user.id,
          :note_body_attributes => {
            :body => "body two",
            :body_html => "<div>body two</div>"
        },
        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["feedback"],
        :incoming => true,
        :private => false
        )
    note.save_note
    remark = @account.survey_remarks.create({
      :account_id => @account.id,
      :note_id => note.id
    })
    remark.id.should_not eql nil
  end
end