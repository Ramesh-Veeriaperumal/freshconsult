require 'spec_helper'

describe Admin::ProductsController do
	integrate_views
	setup :activate_authlogic
	self.use_transactional_fixtures = false

	before(:all) do
		@test_product = Factory.build(:product, :name => Faker::Name.name, :description => Faker::Lorem.paragraph, :account_id => @account.id)
		@test_product.save(false)
		test_email_config = Factory.build(:email_config, :to_email => "test_product@localhost.freshpo.com", :reply_email => "test_product@localhost.freshpo.com",
			                                             :primary_role =>"true", :name => @test_product.name, :product_id => @test_product.id,
			                                             :account_id => @account.id,:active=>"true")
		test_email_config.save(false)
		test_portal = Factory.build(:portal, :name=> "New test_product portal", :portal_url => "test.product.com", :language=>"en",
			                                 :product_id => @test_product.id, :forum_category_id=>"", :solution_category_ids=>[""],:account_id => @account.id,
			                                 :preferences=>{ :logo_link=>"", :contact_info=>"", :header_color=>"#252525", :tab_color=>"#006063", 
                                     		            :bg_color=>"#efefef" })
		test_portal.save(false)
		@test_product_1 = Factory.build(:product, :name => "New Product without Portal", :description => Faker::Lorem.paragraph, :account_id => @account.id)
		@test_product_1.save(false)
		email_config = Factory.build(:email_config, :to_email => "pdt_without_portal@localhost.freshpo.com", :reply_email => "pdt_without_portal@localhost.freshpo.com",
			                                             :primary_role =>"true", :name => @test_product_1.name, :product_id => @test_product_1.id,
			                                             :account_id => @account.id,:active=>"true")
		email_config.save(false)
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
		post :create, { :product =>{ :name =>"Fresh Product", :description => "new innovation for service world", 
			                         :email_configs_attributes=>{ 
			                         	"0"=>{ :reply_email =>"newproduct@localhost.freshpo.com", :primary_role =>"true", :_destroy=>"false", 
			                         		   :to_email=>"newproduct@localhost.freshpo.com",:group_id=>"" }
                                     }, 
                                     :enable_portal=>"1", 
                                     :portal_attributes=>{ :name=>"Fresh Portal", :portal_url=>"support.product.com", :language=>"en", 
                                     	:forum_category_id=>"", :solution_category_ids=>[""], 
                                        :preferences=>{ :logo_link=>"", :contact_info=>"", :header_color=>"#252525", :tab_color=>"#006063", 
                                     		            :bg_color=>"#efefef" }
                                     }
                        }
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

	it "should not create Product" do
		post :create, { :product =>{ :name =>"Fresh Org", :description => Faker::Lorem.paragraph, 
			                         :email_configs_attributes=>{ 
			                         	"0"=>{ :reply_email =>"", :primary_role =>"true", :_destroy=>"false", 
			                         		   :to_email=>"",:group_id=>"" }
                                     }, 
                                     :enable_portal=>"0", 
                                     :portal_attributes=>{ :name=>"", :portal_url=>"", :language=>"en", :forum_category_id=>"", 
                                     	:solution_category_ids=>[""], 
                                        :preferences=>{ :logo_link=>"", :contact_info=>"", :header_color=>"#252525", :tab_color=>"#006063", 
                                     		            :bg_color=>"#efefef" }
                                     }
                        }
		}
		new_product = Product.find_by_name("Fresh Org")
		new_product.should be_nil
		response.body.should =~ /New Product/
		response.should be_success
	end


	it "should not update a product" do
		put :update, {
			:id => @test_product.id,
			:product =>{ :name =>"Updated: Fresh test Product", :description => @test_product.description,
				         :email_configs_attributes=>{ 
			                "0"=>{ :id => @test_product.email_configs.first.id,:reply_email => "", 
			                       :primary_role =>"true", :_destroy=>"false", :to_email=> "",
			                       :group_id=>"" }
                         },
                         :enable_portal =>"1",
                         :portal_attributes=>{ :name=>@test_product.portal.name, :portal_url=>"support.product.test.com", 
                         	:language=> @test_product.portal.language, :forum_category_id=>"", :solution_category_ids=>[""], 
                            :preferences=>{ :logo_link=>"", :contact_info=>"", :header_color=>"#009999", :tab_color=>"#006063", 
                                     		            :bg_color=>"#FFCCFF" },
                            :id => @test_product.portal.id         
                          }
                        }
		}
		@test_product.reload
		@test_product.name.should_not eql "Updated: Fresh test Product"
		@test_product.email_configs.should_not be_nil
		@test_product.portal.portal_url.should eql "test.product.com"
		@test_product.portal.preferences[:header_color].should eql "#252525"
		@test_product.portal.preferences[:bg_color].should_not eql "#FFCCFF"
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

	it "should update product with portal disabled" do
		put :update, {
			:id => @test_product_1.id,
			:product =>{ :name =>"Updated: Product with portal disabled", :description => @test_product_1.description,
				         :email_configs_attributes=>{ 
			                "0"=>{ :id => @test_product_1.email_configs.first.id,:reply_email =>@test_product_1.email_configs.first.reply_email, 
			                       :primary_role =>"true", :_destroy=>"false", :to_email=>@test_product_1.email_configs.first.to_email,
			                       :group_id=>"" }
                         },
                         :enable_portal =>"0",
                         :portal_attributes=>{ :name=>"new Portal", :portal_url=>"new.support.product.com", :language=>"en", 
                                     	:forum_category_id=>"", :solution_category_ids=>[""], 
                                        :preferences=>{ :logo_link=>"", :contact_info=>"", :header_color=>"#252525", :tab_color=>"#006063", 
                                     		            :bg_color=>"#efefef" },
                                        :id => @test_product_1.portal.id
                                     }
                        }

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