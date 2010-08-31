require 'test_helper'

class Helpdesk::ArticlesControllerTest < ActionController::TestCase
  context "all permissions granted" do
    setup do
      stub_user
      allow_all
      set_referrer
      @article = Helpdesk::Article.first
    end

    context "on get to :index" do
      setup do
        get :index
      end
      should_assign_to :items
      should_respond_with :success
      should_render_template :index
      should_not_set_the_flash
    end

    context "on get to show with valid id" do
      setup do
        get :show, :id => @article.id
      end
      should_redirect_to 'edit_helpdesk_article_path(@item)'
    end

    context "on get edit with valid id" do
      setup do
        get :edit, :id => @article.id
      end
      should_respond_with :success
      should_render_template :edit
      should_render_a_form
      should_not_show_form_errors
      should_assign_to :item, :article
      should "load correct article" do
        assert_equal @article, assigns(:article)
      end
    end

    context "on get to new" do
      setup do
        get :new
      end
      should_assign_to :item, :article
      should_render_a_form
      should_render_template :new
      should_not_show_form_errors
    end

    context "on put to update with invalid id" do
      setup do
        assert_raise ActiveRecord::RecordNotFound do
          put :update, :id => "not a valid id"
        end
      end
      should_not_assign_to :item, :article
      should_not_set_the_flash
    end

    context "on valid put to update" do
      setup do
        @params = {:title => 'Billy Jean', :body => "She's just a girl who thinks I am the one"}
        put :update, :id => @article.to_param, :helpdesk_article => @params
      end
      should_assign_to :item, :article
      should_redirect_to "helpdesk_articles_url"
      should_set_the_flash_to "The article has been updated"
      should_not_change "Helpdesk::Article.count"
      should "update article with @params" do
        @article.reload
        @params.each { |k, v| assert_equal v, @article.send(k) }
      end
    end

    context "on valid put to update with save_and_create specified" do
      setup do
        @params = {:title => 'Billy Jean', :body => "She's just a girl who thinks I am the one"}
        put :update, :id => @article.to_param, :helpdesk_article => @params, :save_and_create => true
      end
      should_assign_to :item, :article
      should_redirect_to "new_helpdesk_article_url"
      should_set_the_flash_to "The article has been updated"
      should_not_change "Helpdesk::Article.count"
      should "update article with @params" do
        @article.reload
        @params.each { |k, v| assert_equal v, @article.send(k) }
      end
    end

    context "on invalid put to update" do
      setup do
        @params = {:title => '', :body => "She's just a girl who thinks I am the one"}
        put :update, :id => @article.to_param, :helpdesk_article => @params
      end
      should_assign_to :item, :article
      should_not_change "Helpdesk::Article.count"
      should_render_a_form
      should_render_template :edit
      should_show_form_errors
      should "not update article with @params" do
        @article.reload
        @params.each { |k, v| assert_not_equal v, @article.send(k) }
      end
    end
    
    context "on valid post to create" do
      setup do
        @params = {:title => 'Billy Jean', :body => "She's just a girl who thinks I am the one"}
        post :create, :helpdesk_article => @params
      end
      should_assign_to :item, :article
      should_redirect_to "helpdesk_articles_url"
      should_set_the_flash_to "The article has been created"
      should_change "Helpdesk::Article.count", 1
      should "create article with @params" do
        article = Helpdesk::Article.last
        @params.each { |k, v| assert_equal v, article.send(k) }
      end
    end

    context "on valid post to create with save_and_create specified" do
      setup do
        @params = {:title => 'Billy Jean', :body => "She's just a girl who thinks I am the one"}
        post :create, :helpdesk_article => @params, :save_and_create => true
      end
      should_assign_to :item, :article
      should_redirect_to "new_helpdesk_article_url"
      should_set_the_flash_to "The article has been created"
      should_change "Helpdesk::Article.count", 1
      should "create article with @params" do
        article = Helpdesk::Article.last
        @params.each { |k, v| assert_equal v, article.send(k) }
      end
    end

    context "on invalid post to create" do
      setup do
        @params = {:title => '', :body => "She's just a girl who thinks I am the one"}
        post :create, :helpdesk_article => @params
      end
      should_assign_to :item, :article
      should_not_change "Helpdesk::Article.count"
      should_render_a_form
      should_render_template :new
      should_show_form_errors
    end

    context "on valid post to create, assigning to guides" do
      setup do
        @guide1 = Helpdesk::Guide.first
        @guide2 = Helpdesk::Guide.last
        @params = {
          :title => 'Billy Jean', 
          :body => "She's just a girl who thinks I am the one",
          :guides => [@guide1.to_param, @guide2.to_param]
        }
        post :create, :helpdesk_article => @params
      end
      should_assign_to :item, :article
      should_redirect_to "helpdesk_articles_url"
      should_set_the_flash_to "The article has been created"
      should_change "Helpdesk::Article.count", :by => 1
      should_change "Helpdesk::ArticleGuide.count", :by => 2
      should_not_change "Helpdesk::Guide.count"
      should "add guides to article" do
        article = Helpdesk::Article.last
        assert_equal 2, article.guides.size 
        assert article.guides.include?(@guide1)
        assert article.guides.include?(@guide2)
        assert @guide1.articles.include?(article)
        assert @guide2.articles.include?(article)
      end
    end

    context "on valid put to update, not in any guides assigning to guides" do
      setup do
        @guide1 = Helpdesk::Guide.first
        @guide2 = Helpdesk::Guide.last
        @article.article_guides.clear
        @params = {
          :title => 'Billy Jean', 
          :body => "She's just a girl who thinks I am the one",
          :guides => [@guide1.to_param, @guide2.to_param]
        }
        put :update, :id => @article.to_param, :helpdesk_article => @params
      end
      should_assign_to :item, :article
      should_redirect_to "helpdesk_articles_url"
      should_set_the_flash_to "The article has been updated"

      should_not_change "Helpdesk::Article.count"
      should_not_change "Helpdesk::Guide.count"

      # There was already one articleguide present. 
      # We deleted it, and replaced it with 2 articleguides
      # for a net gain of 1
      should_change "Helpdesk::ArticleGuide.count", :by => 1

      should "add guides to article" do
        @article.reload
        assert_equal 2, @article.guides.size 
        assert @article.guides.include?(@guide1)
        assert @article.guides.include?(@guide2)
        assert @guide1.articles.include?(@article)
        assert @guide2.articles.include?(@article)
      end
    end

    context "on delete to destroy with multiple valid ids" do
      setup do
        @articles = Helpdesk::Article.all
        delete :destroy, :ids => @articles.map { |t| t.to_param }
      end

      should_assign_to :items, :articles

      should "set flash" do
        assert_match(/articles were deleted/, flash[:notice])
      end

      should "assign correct articles" do
        assert_equal @articles, assigns(:articles)
      end

      should "have deleted articles" do
        @articles.each { |t| assert !Helpdesk::Article.find_by_id(t.id) }
      end
    end

    context "on delete to destroy with no valid ids" do
      setup do
        delete :destroy, :ids => ['invalid 1', 'invalid 2']
      end

      should_assign_to :items, :articles

      should "set flash" do
        assert_match(/0 articles were deleted/, flash[:notice])
      end

      should "assign correct articles" do
        assert_equal [], assigns(:articles)
      end

      should_not_change "Helpdesk::Article.count"
    end

    
    context "on get to autocomplete" do
      setup do
        get :autocomplete, :v => "autogen"
      end
      
      should_respond_with :success
      should_respond_with_content_type "application/json"

      should "return correct json response" do
        items = Helpdesk::Article.find(
          :all, 
          :conditions => ["title like ?", "%autogen%"], 
          :limit => 30
        )
        correct = {"results" => items.map {|i| {'id' => i.to_param, 'value' => i.title} } } 
        assert_equal correct, ActiveSupport::JSON.decode(@response.body)
      end

    end

    context "controller's private and protected methods made public" do
      setup { publicize_controller_methods }
      teardown { privatize_controller_methods }

      should "return class_name from Namespace::ClassName" do
        assert_equal "article", @controller.cname
      end

      should "return namespace_class_name from Namespace::ClassName" do
        assert_equal "helpdesk_article", @controller.nscname
      end

      should "return correct scoper" do
        assert_same Helpdesk::Article, @controller.scoper
      end

      should "find_by_id_token when load by param is called" do
        Helpdesk::Article.expects(:find_by_id).with(999).returns(:some_value)
        assert_equal :some_value, @controller.load_by_param(999)
      end

      should "fetch item when load_item called" do
        Helpdesk::Article.expects(:find_by_id).with(999).returns(:some_value)
        @controller.expects(:params).returns({:id => 999})
        assert_equal :some_value, @controller.load_item
      end

      should "raise RecordNotFound if load_item called with invalid id" do
        Helpdesk::Article.expects(:find_by_id).with(999).returns(nil)
        @controller.expects(:params).returns({:id => 999})
        assert_raise ActiveRecord::RecordNotFound do
          @controller.load_item
        end
      end

      should "build a new article from params" do
        @controller.expects(:params).returns({'helpdesk_article' => {'title' => "a title", 'body' => 'a body'}})
        article = @controller.build_item
        assert_equal "a title", article.title
        assert_equal "a body", article.body
      end

      should "return correct autocomplete search field" do
        assert_equal "title", @controller.autocomplete_field
      end

      should "return correct autocomplete scoper" do
        assert_same Helpdesk::Article, @controller.autocomplete_scoper
      end



    end
  end
end
