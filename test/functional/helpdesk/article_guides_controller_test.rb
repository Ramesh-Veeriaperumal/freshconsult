require 'test_helper'

class Helpdesk::ArticleGuidesControllerTest < ActionController::TestCase
  context "all permissions granted" do
    setup do
      stub_user
      allow_all
      set_referrer
      @article = Helpdesk::Article.first
      @guide = Helpdesk::Guide.first
      @article.guides.clear
    end

    context "on valid post to create" do
      setup do
        post :create, :article_id => @article.id, :guide_id => @guide.id
      end

      should_redirect_to back
      should "set flash" do
        assert_equal "1 article was assigned to #{@guide.name}", flash[:notice]
      end
      should_change "Helpdesk::ArticleGuide.count", :by => 1
      should "add article to guide" do
        @guide.reload
        assert @guide.articles.include?(@article)
      end
    end

    context "on valid post to create duplicate" do
      setup do
        @guide.articles << @article
        post :create, :article_id => @article.id, :guide_id => @guide.id
      end

      should_redirect_to back
      should_change "Helpdesk::ArticleGuide.count", :by => 1
    end

    context "on post to create invalid article_id" do
      should "respond with not found" do
        assert_raise ActiveRecord::RecordNotFound do
          post :create, :article_id => "wrong!", :guide_id => @guide.id
        end
      end
    end

    context "on post to create invalid guide_id" do
      should "respond with not found" do
        assert_raise ActiveRecord::RecordNotFound do
          post :create, :article_id => @article.id, :guide_id => "wrong!"
        end
      end
    end
  end
end
