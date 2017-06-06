require 'spec_helper'

describe Search::V2::Mobile::RelatedArticlesController do
  self.use_transactional_fixtures = false
  let(:params) { {:format =>'json'} }

  before(:all) do
    @test_ticket = create_ticket({ :status => 2, :subject => "Sample subject" , :description => "Sample description"})
    @test_category_meta = create_category
    @test_folder_meta = create_folder( {:category_id => @test_category_meta.id } )
    @test_article_meta = create_article( {
                          :title => "Sample subject", 
                          :description => "Sample description", 
                          :folder_id => @test_folder_meta.id
                        } )
    @product1 = create_product({:portal_url => "testportal1.com"})
    @product2 = create_product({:portal_url => "testportal2.com"})
  end

  before(:each) do
    api_login
  end

  it "should have article url in the response" do
    get :index, params.merge(:ticket => @test_ticket.display_id)
    json_response.each do |article|
      article["url"].should_not be_nil
      article["url"].should eql(@test_ticket.article_url(@account.solution_article_meta.where(:id => article["id"]).first.primary_article))
    end
  end

  it "should return the ticket's product portal url if the article's category is associated to that portal" do
    @test_category_meta.update_attributes({:portal_ids => [@product1.portal.id]})
    @test_ticket.update_attributes({:product_id => @product1.id})
    get :index, params.merge(:ticket => @test_ticket.display_id)
    json_response.each do |article|
      article["url"].should_not be_nil
      URI.parse(article["url"]).host.should eql(@product1.portal_url)
    end
  end

  it "should return the url of the portal that the article's category is associated to if it is not associated to the ticket's product portal" do
    @test_category_meta.update_attributes({:portal_ids => [@product1.portal.id]})
    @test_ticket.update_attributes({:product_id => @product2.id})
    get :index, params.merge(:ticket => @test_ticket.display_id)
    json_response.each do |article|
      article["url"].should_not be_nil
      URI.parse(article["url"]).host.should eql(@product1.portal_url)
    end
  end

  it "should return the main portal url if the article's cateogory is associated to the main portal" do
    @test_category_meta.update_attributes({:portal_ids => [@account.main_portal.id]})
    @test_ticket.update_attributes({:product_id => nil})
    get :index, params.merge(:ticket => @test_ticket.display_id)
    json_response.each do |article|
      article["url"].should_not be_nil
      URI.parse(article["url"]).host.should eql(@account.full_domain)
    end
  end

  it "should return the url of the portal that the article's category is associated to if it is not associated to the main portal" do
    @test_category_meta.update_attributes({:portal_ids => [@product1.portal.id]})
    @test_ticket.update_attributes({:product_id => nil})
    get :index, params.merge(:ticket => @test_ticket.display_id)
    json_response.each do |article|
      article["url"].should_not be_nil
      URI.parse(article["url"]).host.should eql(@product1.portal_url)
    end
  end
end
