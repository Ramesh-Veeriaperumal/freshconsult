require 'spec_helper'

describe Admin::ProductsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @portal_url = "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"

    @test_category_1 = create_test_category
    @test_category_2 = create_test_category

    @test_product = create_product({:email => "#{Faker::Internet.domain_word}@#{@account.full_domain}",
                                    :portal_name=> "New test_product portal", 
                                    :portal_url => @portal_url})
    @test_product_1 = create_product({:name => "New Product without Portal", 
                                      :email => "#{Faker::Internet.domain_word}@#{@account.full_domain}"})
    @test_product_2 = create_product({:email => "#{Faker::Internet.domain_word}@#{@account.full_domain}",
                                    :portal_name=> "New test_product portal 1", 
                                    :portal_url => "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}",
                                    :enable_portal => "1",
                                    :forum_category_id => @test_category_1.id
                                    })
    @test_product_3 = create_product({:email => "#{Faker::Internet.domain_word}@#{@account.full_domain}",
                                    :portal_name=> "New test_product portal 2", 
                                    :portal_url => "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}",
                                    :enable_portal => "1",
                                    :forum_category_id => ""
                                    })
    @test_product_4 = create_product({:email => "#{Faker::Internet.domain_word}2@#{@account.full_domain}",
                                    :portal_name=> "New test_product portal 3", 
                                    :portal_url => "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}",
                                    :enable_portal => "1",
                                    :forum_category_id => @test_category_1.id
                                    })
  end

  before(:each) do
    login_admin
    stub_s3_writes
  end

  it "should list all products" do
    get :index
    response.body.should =~ /Products/
    response.should be_success
  end

  it "should create new products" do
    get :new
    response.body.should =~ /Product Support Emails/
    response.should be_success
  end

  it "should create Product" do
    product_email = "#{Faker::Internet.domain_word}@#{@account.full_domain}"
    portal_url = "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"
    post :create, :product => product_params({:name => "Fresh Product", 
                                              :description => "new innovation for service world", 
                                              :email => product_email, 
                                              :portal_name=> "Fresh Portal", 
                                              :portal_url=> portal_url})
    session[:flash][:notice].should eql "The product has been created."
    new_product = @account.products.find_by_name("Fresh Product")
    new_product.should_not be_nil
    new_product.portal.should_not be_nil
    new_product.email_configs.should_not be_nil
    new_product.email_configs.first.reply_email.should eql product_email
    new_product.portal.name.should eql "Fresh Portal"
    new_product.portal.portal_url.should eql portal_url
    new_product.portal.preferences[:header_color].should eql "#252525"
    response.body.should =~ /redirected/
  end

  it "should not create Product without reply_email" do
    post :create, { :product => product_params({:name =>"Fresh Org",:enable_portal=>"0"})
    }
    new_product = @account.products.find_by_name("Fresh Org")
    new_product.should be_nil
    response.body.should =~ /New Product/
    response.should be_success
  end


  it "should not update a product without reply_email" do
    put :update, {
      :id => @test_product.id,
      :product => product_params({:name =>"Updated: Fresh test Product", 
                                  :description => @test_product.description,
                                  :portal_name=>@test_product.portal.name, 
                                  :portal_url=> Faker::Internet.url,
                                  :email_configs_id => @test_product.email_configs.first.id, 
                                  :portal_id => @test_product.portal.id,
                                  :header_color=>"#009999" })
    }
    @test_product.reload
    @test_product.name.should_not eql "Updated: Fresh test Product"
    @test_product.email_configs.should_not be_nil
    @test_product.portal.portal_url.should eql @portal_url
    @test_product.portal.preferences[:header_color].should eql "#252525"
    response.body.should =~ /Edit Product/
    response.should be_success
  end

  it "should update product without portal(disabled)" do
    put :update, {
      :id => @test_product_1.id,
      :product =>{ :name =>"Updated: Product without Portal(disabled)", 
                   :description => @test_product_1.description,
                   :email_configs_attributes=>{ 
                      "0"=>{ :id => @test_product_1.email_configs.first.id,
                             :reply_email =>@test_product_1.email_configs.first.reply_email, 
                             :primary_role =>"true", 
                             :_destroy=>"false", 
                             :to_email=>@test_product_1.email_configs.first.to_email,
                             :group_id=>"" }
                         },
                    :enable_portal =>"0"
                  }
    }
      @test_product_1.reload
      session[:flash][:notice].should eql "The product has been updated."
      @test_product_1.name.should eql "Updated: Product without Portal(disabled)"
      @test_product_1.portal.should be_nil
      response.body.should =~ /redirected/
  end

  it "should update product without portal(enabled)" do
    put :update, {
      :id => @test_product_1.id,
      :product =>{ :name =>"Updated: Product without Portal(enabled)", :description => @test_product_1.description,
                 :email_configs_attributes=>{ 
                      "0"=>{ :id => @test_product_1.email_configs.first.id,:reply_email =>@test_product_1.email_configs.first.reply_email, 
                             :primary_role =>"true", :_destroy=>"false", :to_email=>@test_product_1.email_configs.first.to_email,
                             :group_id=>"" }
                         },
                         :enable_portal =>"1"
                        }
    }
      @test_product_1.reload
      session[:flash][:notice].should eql "The product has been updated."
      @test_product_1.name.should eql "Updated: Product without Portal(enabled)"
      @test_product_1.portal.should_not be_nil
      response.body.should =~ /redirected/
  end

  it "should destory portal when portal is disabled" do
    put :update, 
        :id => @test_product_1.id,
        :product => product_params({:name =>"Updated: Product with portal disabled", 
                                    :description => @test_product_1.description,
                                    :enable_portal =>"0",
                                    :portal_name=>"new Portal", 
                                    :portal_url=> Faker::Internet.url , 
                                    :email =>@test_product_1.email_configs.first.reply_email,
                                    :email_configs_id => @test_product_1.email_configs.first.id, 
                                    :portal_id => @test_product_1.portal.id})
    @test_product_1.reload
    @test_product_1.portal.should be_nil
  end

  it "should update a product" do
    portal_url = "#{Faker::Internet.domain_word}.#{Faker::Internet.domain_name}"
    put :update, 
        :id => @test_product.id,
        :product => { :name =>"Updated: Fresh test Product", 
                      :description => @test_product.description,
                      :email_configs_attributes=>{ 
                        "0" => { :id => @test_product.email_configs.first.id,
                                 :reply_email =>@test_product.email_configs.first.reply_email, 
                                 :primary_role =>"true", 
                                 :_destroy=>"false", 
                                 :to_email=>@test_product.email_configs.first.to_email,
                                 :group_id=>"" 
                                }
                      },
                      :enable_portal =>"1",
                      :portal_attributes=>
                        { :name=>@test_product.portal.name, 
                          :portal_url=> portal_url, 
                          :language=> @test_product.portal.language, 
                          :forum_category_id=>"", 
                          :solution_category_ids=>[""], 
                          :logo_attributes => { :content => 
                            fixture_file_upload('files/image4kb.png', 'image/png')},
                          :fav_icon_attributes => {:content => 
                            fixture_file_upload('files/image33kb.jpg', 'image/jpg')},
                          :preferences=>{ :logo_link=>"", 
                                          :contact_info=>"", 
                                          :header_color=>"#009999", 
                                          :tab_color=>"#006063", 
                                          :bg_color=>"#FFCCFF" },
                          :id => @test_product.portal.id
                      }
                    }
    @test_product.reload
    session[:flash][:notice].should eql "The product has been updated."
    @test_product.name.should eql "Updated: Fresh test Product"
    @test_product.email_configs.should_not be_nil
    @test_product.portal.portal_url.should eql portal_url
    @test_product.portal.preferences[:header_color].should eql "#009999"
    @test_product.portal.preferences[:bg_color].should eql "#FFCCFF"
    logo_icon = @account.attachments.find(:all,:conditions=>["attachable_id = ? and attachable_type = ?", "#{@test_product.portal.id}", "Portal"])
    logo_icon.should_not be_nil
    response.body.should =~ /redirected/
  end

  it "should delete_logo of the product" do
    delete :delete_logo, :id => @test_product.portal.id
    logo = @account.attachments.first(:conditions=>["attachable_id = ? and attachable_type = ? and description = ?", 
                                                           "#{@test_product.portal.id}", "Portal", "logo"])
    logo.should be_nil
  end

  it "should delete_favicon of the product" do
    delete :delete_favicon, :id => @test_product.portal.id
    fav_icon = @account.attachments.first(:conditions=>["attachable_id = ? and attachable_type = ? and description = ?", 
                                                           "#{@test_product.portal.id}", "Portal", "fav_icon"])
    fav_icon.should be_nil
  end

  it "should destroy a product" do
    post :destroy, :id => @test_product.id
    flash[:notice].should eql "The product has been deleted."
    response.should redirect_to "/admin/products"
    @account.products.find_by_id(@test_product.id).should be_nil
  end

  describe "associating forum category" do
    it "should not create a record in portal_forum_categories" do
      result = @test_product_3.portal.portal_forum_categories
      result.length.should eql 0
    end

    it "should create a record in portal forum categories table" do
      result = @test_product_2.portal.portal_forum_categories
      result.length.should eql 1
      result.first.forum_category_id.should eql @test_product_2.portal.forum_category_id
    end

    it "should create one record and delete another record in portal forum categories table when forum_category_id is updated from 1 value to another" do
      @test_product_4.portal.forum_category_id = @test_category_2.id
      @test_product_4.save

      put :update, 
          :id => @test_product_4.id,
          :product => { :portal_attributes =>
                          { :forum_category_id => @test_category_1.id
                        }
                      }

      @test_product_4.reload

      result = @test_product_4.portal.portal_forum_categories
      result.length.should eql 1
      result.first.forum_category_id.should eql @test_product_4.portal.forum_category_id
    end

    it "should create a record in portal forum categories when forum_category_id is updated to some value from nil" do
      # Making this nil and then testing it.
      @test_product_4.portal.forum_category_id = nil
      @test_product_4.save

      put :update, 
          :id => @test_product_4.id,
          :product => { :portal_attributes =>
                          { :forum_category_id => @test_category_2.id
                        }
                      }

      @test_product_4.reload

      result = @test_product_4.portal.portal_forum_categories
      result.length.should eql 1
      result.first.forum_category_id.should eql @test_product_4.portal.forum_category_id
    end

    it "should delete a record from portal forum categories when forum_category_id is updated to nil" do
      @test_product_4.portal.forum_category_id = @test_category_1.id
      @test_product_4.save

      put :update, 
          :id => @test_product_4.id,
          :product => { :portal_attributes =>
                          { :forum_category_id => ""
                        }
                      }

      @test_product_4.reload

      result = @test_product_4.portal.portal_forum_categories
      result.length.should eql 0
    end
  end
end