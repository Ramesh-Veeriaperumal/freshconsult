require 'spec_helper'

describe Admin::ProductsController do
	integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@test_product = create_product({:email => "test_product@localhost.freshpo.com",:portal_name=> "New test_product portal", 
			                            :portal_url => "test.product.com"})
		@test_product_1 = create_product({:name => "New Product without Portal", :email => "pdt_without_portal@localhost.freshpo.com"})
	end

	before(:each) do
		login_admin
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
		post :create, { :product => product_params({:name =>"Fresh Product", :description => "new innovation for service world", 
													:email =>"newproduct@localhost.freshpo.com", :portal_name=>"Fresh Portal", 
													:portal_url=>"support.product.com"})
		}
		response.session[:flash][:notice].should eql "The product has been created."
		new_product = Product.find_by_name("Fresh Product")
		new_product.should_not be_nil
		new_product.portal.should_not be_nil
		new_product.email_configs.should_not be_nil
		new_product.email_configs.first.reply_email.should eql "newproduct@localhost.freshpo.com"
		new_product.portal.name.should eql "Fresh Portal"
		new_product.portal.portal_url.should eql "support.product.com"
		new_product.portal.preferences[:header_color].should eql "#252525"
		response.body.should =~ /redirected/
	end

	it "should not create Product without reply_email" do
		post :create, { :product => product_params({:name =>"Fresh Org",:enable_portal=>"0"})
		}
		new_product = Product.find_by_name("Fresh Org")
		new_product.should be_nil
		response.body.should =~ /New Product/
		response.should be_success
	end


	it "should not update a product without reply_email" do
		put :update, {
			:id => @test_product.id,
			:product => product_params({:name =>"Updated: Fresh test Product", :description => @test_product.description,
													:portal_name=>@test_product.portal.name, :portal_url=>"support.product.test.com",
													:email_configs_id => @test_product.email_configs.first.id, :portal_id => @test_product.portal.id,
													:header_color=>"#009999" })
		}
		@test_product.reload
		@test_product.name.should_not eql "Updated: Fresh test Product"
		@test_product.email_configs.should_not be_nil
		@test_product.portal.portal_url.should eql "test.product.com"
		@test_product.portal.preferences[:header_color].should eql "#252525"
		response.body.should =~ /Edit Product/
		response.should be_success
	end

	it "should update product without portal(disabled)" do
		put :update, {
			:id => @test_product_1.id,
			:product =>{ :name =>"Updated: Product without Portal(disabled)", :description => @test_product_1.description,
				         :email_configs_attributes=>{ 
			                "0"=>{ :id => @test_product_1.email_configs.first.id,:reply_email =>@test_product_1.email_configs.first.reply_email, 
			                       :primary_role =>"true", :_destroy=>"false", :to_email=>@test_product_1.email_configs.first.to_email,
			                       :group_id=>"" }
                         },
                         :enable_portal =>"0"
                        }
		}
	    @test_product_1.reload
	    response.session[:flash][:notice].should eql "The product has been updated."
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
	    response.session[:flash][:notice].should eql "The product has been updated."
	    @test_product_1.name.should eql "Updated: Product without Portal(enabled)"
	    @test_product_1.portal.should_not be_nil
	    response.body.should =~ /redirected/
	end

	it "should destory portal when portal is disabled" do
		put :update, {
			:id => @test_product_1.id,
			:product => product_params({:name =>"Updated: Product with portal disabled", :description => @test_product_1.description,:enable_portal =>"0",
										:portal_name=>"new Portal", :portal_url=>"new.support.product.com", :email =>@test_product_1.email_configs.first.reply_email,
										:email_configs_id => @test_product_1.email_configs.first.id, :portal_id => @test_product_1.portal.id})

		}
		@test_product_1.reload
		@test_product_1.portal.should be_nil
	end

	it "should update a product" do
		put :update, {
			:id => @test_product.id,
			:product =>{ :name =>"Updated: Fresh test Product", :description => @test_product.description,
				         :email_configs_attributes=>{ 
			                "0"=>{ :id => @test_product.email_configs.first.id,:reply_email =>@test_product.email_configs.first.reply_email, 
			                       :primary_role =>"true", :_destroy=>"false", :to_email=>@test_product.email_configs.first.to_email,
			                       :group_id=>"" }
                         },
                         :enable_portal =>"1",
                         :portal_attributes=>{ :name=>@test_product.portal.name, :portal_url=>"support.product.test.com", 
                         	:language=> @test_product.portal.language, :forum_category_id=>"", :solution_category_ids=>[""], 
                         	:logo_attributes => {:content => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png', 
                                        'image/png')},
                         	:fav_icon_attributes => {:content => Rack::Test::UploadedFile.new('spec/fixtures/files/image33kb.jpg', 
                                        'image/jpg')},
                            :preferences=>{ :logo_link=>"", :contact_info=>"", :header_color=>"#009999", :tab_color=>"#006063", 
                                     		            :bg_color=>"#FFCCFF" },
                            :id => @test_product.portal.id         
                          }
                        }
		}
		@test_product.reload
		response.session[:flash][:notice].should eql "The product has been updated."
		@test_product.name.should eql "Updated: Fresh test Product"
		@test_product.email_configs.should_not be_nil
		@test_product.portal.portal_url.should eql "support.product.test.com"
		@test_product.portal.preferences[:header_color].should eql "#009999"
		@test_product.portal.preferences[:bg_color].should eql "#FFCCFF"
		logo_icon = Helpdesk::Attachment.find(:all,:conditions=>["attachable_id = ? and attachable_type = ?", "#{@test_product.portal.id}", "Portal"])
		logo_icon.should_not be_nil
		response.body.should =~ /redirected/
	end

	it "should delete_logo of the product" do
		delete :delete_logo, :id => @test_product.portal.id
		logo = Helpdesk::Attachment.first(:conditions=>["attachable_id = ? and attachable_type = ? and description = ?", 
			                                                     "#{@test_product.portal.id}", "Portal", "logo"])
		logo.should be_nil
	end

	it "should delete_favicon of the product" do
		delete :delete_favicon, :id => @test_product.portal.id
		fav_icon = Helpdesk::Attachment.first(:conditions=>["attachable_id = ? and attachable_type = ? and description = ?", 
			                                                     "#{@test_product.portal.id}", "Portal", "fav_icon"])
		fav_icon.should be_nil
	end
end