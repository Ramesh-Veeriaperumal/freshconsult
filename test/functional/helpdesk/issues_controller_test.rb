require 'test_helper'

class Helpdesk::IssuesControllerTest < ActionController::TestCase

  context "all permissions granted" do
    setup do
      stub_user
      allow_all
      set_referrer
    end

    context "on get to :index with no filters or search terms specified" do
      setup do
        get :index
      end
      should_assign_to :items
      should_respond_with :success
      should_render_template :index
      should_not_set_the_flash
    end

    context "on get to :show with invalid issue id" do
      setup do
        Helpdesk::Issue.expects(:find_by_id).with(666).returns(nil)
        assert_raise ActiveRecord::RecordNotFound do
          get :show, :id => 666
        end
      end
      should_not_assign_to :item, :issue
      should_not_set_the_flash
    end

    context "on get to :show with valid issue id" do
      setup do
        @issue = new_issue
        Helpdesk::Issue.stubs(:find_by_id).with(42).returns(@issue)
        get :show, :id => 42
      end

      should_respond_with :success
      should_not_set_the_flash
      should_render_template :show

      should "assign issue to instance vars" do
        assert_same @issue, assigns(:item)
        assert_same @issue, assigns(:issue)
      end
    end

    context "without rendering" do 
      setup do
        @controller.stubs(:render)
        @items = mock
      end

      should "Get :index once with each filter" do
        [
          [:open, :unassigned],
          [:open, :responded_by],
          [:open, :visible],
          [:all, :unassigned],
          [:all, :responded_by],
          [:all, :visible],
          [:all, :deleted]
        ].each do |f|
          Helpdesk::Issue.expects(:filter).with(f, @user).returns(@items)
          Helpdesk::Issue.expects(:search).with(@items, nil, nil).returns(@items)
          @items.expects(:paginate).returns(@items)
          get :index, :filters => f
          assert_same @items, assigns(:items)
        end
      end

      should "Get :index once with each search field" do
        [:name, :description].each do |f|
          Helpdesk::Issue.expects(:filter).with([:open, :visible], @user).returns(@items)
          Helpdesk::Issue.expects(:search).with(@items, f, "abc").returns(@items)
          @items.expects(:paginate).returns(@items)
          get :index, :f => f, :v => "abc"
          assert_same @items, assigns(:items)
        end
      end


      should "Get :index once with each sort field" do
        Helpdesk::Issue::SORT_SQL_BY_KEY.each do |k, s|
          Helpdesk::Issue.expects(:filter).with([:open, :visible], @user).returns(@items)
          Helpdesk::Issue.expects(:search).with(@items, nil, nil).returns(@items)
          @items.expects(:paginate).with(:page => '1', :order => s, :per_page => 10).returns(@items)
          get :index, :page => 1, :sort => k
          assert_same @items, assigns(:items)
        end
      end
    end

    context "on :put to :assign with single valid id and no owner_id specified" do
      setup do
        @issue = new_issue_for_assign
        Helpdesk::Issue.expects(:find_by_id).times(2).with(999).returns(@issue)
        put :assign, :id => 999
      end

      should_assign_to :items, :issues
      should_set_the_flash_to "1 issue was assigned to Joe Bob."

      should "assign loaded issue to @items and @issues" do
        assert_equal [@issue], assigns(:issues)
        assert_equal [@issue], assigns(:items)
      end
    end

    context "on :put to :assign with multiple valid ids and no owner_id specified" do
      setup do
        @issues = (1..10).map do |i|
          t = new_issue_for_assign
          Helpdesk::Issue.expects(:find_by_param).times(2).with("#{i}").returns(t)
          t
        end
        put :assign, :ids => %w{1 2 3 4 5 6 7 8 9 10}
      end

      should_assign_to :items, :issues
      should_redirect_to back
      should_set_the_flash_to "10 issues were assigned to Joe Bob."

      should "assign loaded issues to @items and @issues" do
        assert_equal @issues, assigns(:issues)
        assert_equal @issues, assigns(:items)
      end
    end

    context "on :put to :assign with multiple valid ids and a valid owner_id specified" do
      setup do
        user = User.new(:name => "Jim Bob")
        user.id = 777
        User.stubs(:find).returns(nil)
        User.expects(:find).with('777').returns(user)
        @issues = (1..10).map do |i|
          t = new_issue_for_assign(user)
          Helpdesk::Issue.stubs(:find_by_id).with(i).returns(t)
          t
        end
        put :assign, :ids => %w{1 2 3 4 5 6 7 8 9 10}, :owner_id => 777
      end

      should_assign_to :items, :issues
      should_redirect_to back
      should_set_the_flash_to "10 issues were assigned to Jim Bob."

      should "assign loaded issues to @items and @issues" do
        assert_equal @issues, assigns(:issues)
        assert_equal @issues, assigns(:items)
      end
    end

    context "on :put to :assign with single invalid id" do
      setup do
        Helpdesk::Issue.expects(:find_by_id).times(2).with(666).returns(nil)
        put :assign, :id => 666
      end
      should_assign_to :items, :issues
      should_redirect_to back
      should_set_the_flash_to "0 issues were assigned to Joe Bob."
      should "assign loaded issue to @items and @issues" do
        assert_equal [], assigns(:issues)
        assert_equal [], assigns(:items)
      end
    end

    context "on :put to :assign with multiple invalid ids" do
      setup do
        10.times do |i|
          Helpdesk::Issue.expects(:find_by_param).times(2).with("#{i}").returns(nil)
        end
        put :assign, :ids => %w{0 1 2 3 4 5 6 7 8 9}
      end

      should_assign_to :items, :issues
      should_redirect_to back
      should_set_the_flash_to "0 issues were assigned to Joe Bob."

      should "assign loaded issue to @items and @issues" do
        assert_equal [], assigns(:issues)
        assert_equal [], assigns(:items)
      end
    end

    context "on :put to :assign with some valid and some invalid ids" do
      setup do
        (1..10).each do |i|
          Helpdesk::Issue.expects(:find_by_param).times(2).with("#{i}").returns(
            i%2==1 ? new_issue_for_assign : nil
          )
        end
        put :assign, :ids => %w{1 2 3 4 5 6 7 8 9 10}
      end

      should_assign_to :items, :issues
      should_redirect_to back
      should_set_the_flash_to "5 issues were assigned to Joe Bob."
    end

    context "on :delete to :empty_trash" do
      setup do
        Helpdesk::Issue.expects(:destroy_all).with(:deleted=>true)
        delete :empty_trash
      end
      should_redirect_to back
      should_set_the_flash_to "All issues in the trash folder were deleted."
    end

    context "on valid post to create" do
      setup do
        @params = {:title => 'New Issue', :description => 'new desc', :status => 1}
        post :create, :helpdesk_issue => @params
      end
      should_assign_to :item, :issue
      should_redirect_to "helpdesk_issue_url(@item)"
      should_set_the_flash_to "The issue has been created"
      should_change "Helpdesk::Issue.count", :by => 1
      should "Create issue with @params" do
        issue = Helpdesk::Issue.last
        @params.each { |k, v| assert_equal v, issue.send(k) }
      end
    end

    context "on valid post to create with save_and_create specified" do
      setup do
        @params = {:title => 'New Issue', :description => 'new desc', :status => 1}
        post :create, :helpdesk_issue => @params, :save_and_create => true
      end
      should_assign_to :item, :issue
      should_redirect_to "new_helpdesk_issue_url"
      should_set_the_flash_to "The issue has been created"
      should_change "Helpdesk::Issue.count", :by => 1
      should "Create issue with @params" do
        issue = Helpdesk::Issue.last
        @params.each { |k, v| assert_equal v, issue.send(k) }
      end
    end

    context "on invalid post to create" do
      setup do
        @params = {:title => '', :description => 'new desc', :status => 1}
        post :create, :helpdesk_issue => @params
      end
      should_assign_to :item, :issue
      should_render_a_form
      should_render_template :new
      should_not_change "Helpdesk::Issue.count"
      should "Build issue with @params" do
        @params.each { |k, v| assert_equal v, assigns(:issue).send(k) }
      end
      should "Show form error messages" do
        assert_select "#errorExplanation"
      end
    end

    context "on get to new" do
      setup do
        get :new
      end
      should_assign_to :item, :issue
      should_render_a_form
      should_render_template :new
      should "not show form error messages" do
        assert_select "#errorExplanation", false
      end
    end

    context "on get to edit with valid id" do
      setup do
        @issue = Helpdesk::Issue.last
        get :edit, :id => @issue.to_param
      end
      should_assign_to :item, :issue
      should "load correct issue" do
        assert_equal @issue.id, assigns(:issue).id
        assert_equal @issue.title, assigns(:issue).title
      end
      should_render_a_form
      should_render_template :edit
      should "not show form error messages" do
        assert_select "#errorExplanation", false
      end
    end

    context "on get to edit with invalid id" do
      setup do
        assert_raise ActiveRecord::RecordNotFound do
          get :edit, :id => "not a valid id"
        end
      end
      should_not_assign_to :item, :issue
      should_not_set_the_flash
    end

    context "on put to update with invalid id" do
      setup do
        assert_raise ActiveRecord::RecordNotFound do
          put :update, :id => "not a valid id"
        end
      end
      should_not_assign_to :item, :issue
      should_not_set_the_flash
    end

    context "on valid put to update" do
      setup do
        @issue = Helpdesk::Issue.new(:title => "Bobby sue", :description => "some desc", :user_id => 1)
        @issue.save!
        @params = {:title => 'Billy Jean', :description => "She's just a girl who thinks I am the one"}
        put :update, :id => @issue.to_param, :helpdesk_issue => @params
      end
      should_assign_to :item, :issue
      should_redirect_to "helpdesk_issue_url(@item)"
      should_set_the_flash_to "The issue has been updated"
      should_change "Helpdesk::Issue.count", 1
      should "Create issue with @params" do
        @issue.reload
        @params.each { |k, v| assert_equal v, @issue.send(k) }
      end
    end

    context "on valid put to update with save_and_create specified" do
      setup do
        @issue = Helpdesk::Issue.new(:title => "Bobby sue", :description => "some desc", :user_id => 1)
        @issue.save!
        @params = {:title => 'Billy Jean', :description => "She's just a girl who thinks I am the one"}
        put :update, :id => @issue.to_param, :helpdesk_issue => @params, :save_and_create => true
      end
      should_assign_to :item, :issue
      should_redirect_to "new_helpdesk_issue_url"
      should_set_the_flash_to "The issue has been updated"
      should_change "Helpdesk::Issue.count", 1
      should "Create issue with @params" do
        @issue.reload
        @params.each { |k, v| assert_equal v, @issue.send(k) }
      end
    end

    context "on invalid put to update" do
      setup do
        @issue = Helpdesk::Issue.new(:title => "Bobby sue", :description => "some desc", :user_id => 1)
        @issue.save!
        @params = {:title => ""}
        put :update, :id => @issue.to_param, :helpdesk_issue => @params
      end
      should_assign_to :item, :issue
      should_change "Helpdesk::Issue.count", 1
      should_render_a_form
      should_render_template :edit
      should "show form error messages" do
        assert_select "#errorExplanation"
      end
    end
    
    context "on delete to destroy with multiple valid ids" do
      setup do
        @issues = (1..10).map do |i|
          t = new_issue
          t.expects(:deleted=).with(true)
          t.expects(:save).returns(true)
          Helpdesk::Issue.expects(:find_by_param).times(2).with("#{i}").returns(t)
          t
        end
        delete :destroy, :ids => %w{1 2 3 4 5 6 7 8 9 10}
      end

      should_assign_to :items, :issues
      should_redirect_to back

      should "set flash" do
        assert_match(/^10 issues were deleted/, flash[:notice])
      end

      should "assign loaded issues to @items and @issues" do
        assert_equal @issues, assigns(:issues)
        assert_equal @issues, assigns(:items)
      end
    end
    
    context "on put to restore with multiple valid ids" do
      setup do
        @issues = (1..10).map do |i|
          t = new_issue
          t.expects(:deleted=).with(false)
          t.expects(:save).returns(true)
          Helpdesk::Issue.expects(:find_by_param).times(2).with("#{i}").returns(t)
          t
        end
        put :restore, :ids => %w{1 2 3 4 5 6 7 8 9 10}
      end

      should_assign_to :items, :issues
      should_redirect_to back

      should "set flash" do
        assert_match(/^10 issues were restored/, flash[:notice])
      end

      should "assign loaded issues to @items and @issues" do
        assert_equal @issues, assigns(:issues)
        assert_equal @issues, assigns(:items)
      end
    end


    context "controller's private and protected methods made public" do
      setup { publicize_controller_methods }
      teardown { privatize_controller_methods }

      should "return class_name from Namespace::ClassName" do
        assert_equal "issue", @controller.cname
      end

      should "return namespace_class_name from Namespace::ClassName" do
        assert_equal "helpdesk_issue", @controller.nscname
      end

      should "return correct scoper" do
        assert_same Helpdesk::Issue, @controller.scoper
      end
    end
  end

private

  def new_issue
    Helpdesk::Issue.create(
      :title => "This is an issue title", 
      :description => "Here's my problem..",
      :user_id => 1
    )
  end

  def new_issue_for_assign(user = false)
    issue = new_issue
    issue.save!
    return issue
  end

end
