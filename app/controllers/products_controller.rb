class ProductsController < ApplicationController
  include ModelControllerMethods
  
  before_filter :form_email, :only => :create
  before_filter :crop_email, :only => :edit
  
  def new
    @product.forum_category = ForumCategory.new
  end
  
  def update
    params[:product][:to_email] = "#{params[:product][:to_email]}@#{current_account.full_domain}"
    
    if @product.update_attributes(params[cname])
      flash[:notice] = "The product has been updated."
      redirect_back_or_default redirect_url
    else
      logger.debug "error while saving #{@product.errors.inspect}"
      render :action => 'edit'
    end
  end
  
  protected
    def scoper
      current_account.products
    end

    def form_email
      @product.to_email = "#{params[:product][:to_email]}@#{current_account.full_domain}"
    end

    def crop_email #by Shan need to revisit.. kinda hack
      e_domain = "@#{current_account.full_domain}"
      @product.to_email = @product.to_email[0, @product.to_email.rindex(e_domain)] if @product.to_email.ends_with?(e_domain)
    end
end
