require 'spec_helper'

describe Admin::PagesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @page_type_array = []
    Portal::Page::PAGE_GROUPS.each do |group_hash|
      group_hash.each do |key, group|
        group.each do |page|
          @page_type_array << Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[page]
        end
      end
    end
  end

  before(:each) do
    login_admin
    @page_type = @page_type_array.sample
    @portal_page_label = Portal::Page::PAGE_TYPE_TOKEN_BY_KEY[@page_type]
    page = @account.main_portal.template.pages.new( :page_type => @page_type )
    @content = File.read("#{Rails.root}/app/views/#{page.default_page}").gsub("h2", "h3")
    @agent.make_current
  end

  it "should update the specified portal page" do
    put :update, :portal_page => { :page_type => @page_type, 
                                   :content => @content }, 
                  :portal_id => @account.main_portal.id, 
                  :id => @page_type
    cached_page = @account.main_portal.template.page_from_cache(@portal_page_label)
    cached_page.should be_an_instance_of(Portal::Page)
    cached_page.content.should be_eql(@content)
  end

  it "should update the specified portal page" do
    restricted_page_type = Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[Portal::Page::RESTRICTED_PAGES.sample]
    put :update, :portal_page => { :page_type => restricted_page_type, 
                                   :content => @content }, 
                  :portal_id => @account.main_portal.id, 
                  :id => restricted_page_type
    response.should redirect_to("http://#{@account.full_domain}/support/login")
  end

  it "should update and publish the specified portal page" do
    put :update, :portal_page => { :page_type => @page_type, 
                                   :content => @content }, 
                  :publish_button => "Save and Publish", 
                  :portal_id => @account.main_portal.id, 
                  :id => @page_type
    cached_page = @account.main_portal.template.page_from_cache(@portal_page_label)
    cached_page.should be_nil
    @account.reload
    @account.portal_pages.find_by_page_type(@page_type).content.should be_eql(@content)
  end

  it "should update and preview the specified portal page" do
    put :update, :portal_page => { :page_type => @page_type, 
                                   :content => @content }, 
                  :preview_button => "Preview",
                  :portal_id => @account.main_portal.id, 
                  :id => @page_type
    cached_page = @account.main_portal.template.page_from_cache(@portal_page_label)
    cached_page.should be_an_instance_of(Portal::Page)
    cached_page.content.should be_eql(@content)
    response.should redirect_to("http://#{@account.full_domain}/support/preview")
  end

  it "should update and preview the specified portal page with no controller" do
    label = Portal::Page::PAGE_TYPE_TOKEN_BY_KEY[3]
    put :update, :portal_page => { :page_type => 3, 
                                   :content => @content }, 
                  :preview_button => "Preview",
                  :portal_id => @account.main_portal.id, 
                  :id => 3
    cached_page = @account.main_portal.template.page_from_cache(label)
    cached_page.should be_an_instance_of(Portal::Page)
    cached_page.content.should be_eql(@content)
    response.should redirect_to("http://#{@account.full_domain}/support/preview")
  end

  it "should soft-reset a page" do
    put :update, :portal_page => { :page_type => @page_type, 
                                   :content => @content }, 
                  :publish_button => "Save and Publish", 
                  :portal_id => @account.main_portal.id, 
                  :id => @page_type
    cached_page = @account.main_portal.template.page_from_cache(@portal_page_label)
    cached_page.should be_nil
    @account.reload
    @account.portal_pages.find_by_page_type(@page_type).content.should be_eql(@content)

    new_content = (@content << Faker::Lorem.characters(10))
    put :update, :portal_page => { :page_type => @page_type, 
                                   :content => new_content }, 
                  :portal_id => @account.main_portal.id, 
                  :id => @page_type
    cached_page = @account.main_portal.template.page_from_cache(@portal_page_label)
    cached_page.should be_an_instance_of(Portal::Page)
    cached_page.content.should be_eql(new_content)

    put :soft_reset, :page_id => @page_type,
                      :page_type => @page_type,
                      :portal_id => @account.main_portal.id,
                      :id => @page_type
    cached_page = @account.main_portal.template.page_from_cache(@portal_page_label)
    cached_page.should be_nil
  end
end
