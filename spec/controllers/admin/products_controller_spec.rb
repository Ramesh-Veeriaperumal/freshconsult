require 'spec_helper'

describe Admin::ProductsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_category_1 = create_test_category
    @test_category_2 = create_test_category
    @test_category_3 = create_test_category
    @test_category_4 = create_test_category

    @ids = [@test_category_1.id, @test_category_2.id]
    @test_product = create_product({:email => "#{Faker::Internet.domain_word}@#{@account.full_domain}"})
    @test_product_1 = create_product({:name => "New Product without Portal", 
                                      :email => "#{Faker::Internet.domain_word}@#{@account.full_domain}"})
    @test_product_2 = create_product({:email => "#{Faker::Internet.domain_word}@#{@account.full_domain}"
                                    })
    @test_product_3 = create_product({:email => "#{Faker::Internet.domain_word}@#{@account.full_domain}"
                                    })
    @test_product_4 = create_product({:email => "#{Faker::Internet.domain_word}2@#{@account.full_domain}"
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
    post :create, :product => product_params({:name => "Fresh Product", 
                                              :description => "new innovation for service world", 
                                              :email => product_email})
    session[:flash][:notice].should eql "The product has been created."
    new_product = @account.products.find_by_name("Fresh Product")
    new_product.should_not be_nil
    new_product.portal.should be_nil
    new_product.email_configs.should_not be_nil
    new_product.email_configs.first.reply_email.should eql product_email
    response.body.should =~ /redirected/
  end

  it "should create Product and redirect to enable portal page" do
    product_email = "#{Faker::Internet.domain_word}@#{@account.full_domain}"
    post :create, {
        :product => product_params({:name => "Product with portal", 
                                                :description => "Portal enable", 
                                                :email => product_email}),
        :enable_portal => true
      }
    session[:flash][:notice].should eql "The product has been created."
    new_product = @account.products.find_by_name("Product with portal")
    new_product.should_not be_nil
    new_product.portal.should be_nil
    new_product.email_configs.should_not be_nil
    new_product.email_configs.first.reply_email.should eql product_email
    response.body.should =~ /redirected/
    response.should redirect_to(enable_admin_portal_index_path(:product => new_product.id, :enable => true))
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
      :product => product_params(
        { :name =>"Updated: Fresh test Product", 
          :description => @test_product.description,
          :email_configs_id => @test_product.email_configs.first.id})
    }
    @test_product.reload
    @test_product.name.should_not eql "Updated: Fresh test Product"
    @test_product.email_configs.should_not be_nil
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
                         }
                  }
    }
      @test_product_1.reload
      session[:flash][:notice].should eql "The product has been updated."
      @test_product_1.name.should eql "Updated: Product without Portal(disabled)"
      @test_product_1.portal.should be_nil
      response.body.should =~ /redirected/
  end

  it "should update product and redirect_to portal enable page" do
    put :update, {
      :id => @test_product_1.id,
      :product =>{ :name =>"Updated: Product to enable Portal", 
                   :description => @test_product_1.description,
                   :email_configs_attributes=>{ 
                      "0"=>{ :id => @test_product_1.email_configs.first.id,
                             :reply_email =>@test_product_1.email_configs.first.reply_email, 
                             :primary_role =>"true", 
                             :_destroy=>"false", 
                             :to_email=>@test_product_1.email_configs.first.to_email,
                             :group_id=>"" }
                         }
                  },
      :enable_portal => true
    }
      @test_product_1.reload
      session[:flash][:notice].should eql "The product has been updated."
      @test_product_1.name.should eql "Updated: Product to enable Portal"
      @test_product_1.portal.should be_nil
      response.body.should =~ /redirected/
      response.should redirect_to(enable_admin_portal_index_path(:product => @test_product_1.id, :enable => true))
  end

  it "should update product without portal(enabled)" do
    put :update, {
      :id => @test_product_1.id,
      :product =>{ :name =>"Updated: Product without Portal(enabled)", :description => @test_product_1.description,
                 :email_configs_attributes=>{ 
                      "0"=>{ :id => @test_product_1.email_configs.first.id,:reply_email =>@test_product_1.email_configs.first.reply_email, 
                             :primary_role =>"true", :_destroy=>"false", :to_email=>@test_product_1.email_configs.first.to_email,
                             :group_id=>"" }
                         }
                        }
    }
      @test_product_1.reload
      session[:flash][:notice].should eql "The product has been updated."
      @test_product_1.name.should eql "Updated: Product without Portal(enabled)"
      @test_product_1.portal.should be_nil
      response.body.should =~ /redirected/
  end

  it "should destory portal when portal is disabled" do
    put :update, 
        :id => @test_product_1.id,
        :product => product_params({:name =>"Updated: Product with portal disabled", 
                                    :description => @test_product_1.description,
                                    :email =>@test_product_1.email_configs.first.reply_email,
                                    :email_configs_id => @test_product_1.email_configs.first.id})
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
                      }
                    }
    @test_product.reload
    session[:flash][:notice].should eql "The product has been updated."
    @test_product.name.should eql "Updated: Fresh test Product"
    @test_product.email_configs.should_not be_nil
    response.body.should =~ /redirected/
  end

  it "should destroy a product" do
    post :destroy, :id => @test_product.id
    flash[:notice].should eql "The product has been deleted."
    response.should redirect_to "/admin/products"
    @account.products.find_by_id(@test_product.id).should be_nil
  end
end