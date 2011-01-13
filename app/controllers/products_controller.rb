class ProductsController < ApplicationController
  include ModelControllerMethods
  
#  def index
#  end
#
#  def new
#  end
#
#  def create
#    p "+++++++++++++++Testing venom ========="
#    if @product.save
#      flash[:notice] = "Product successfully created."
#      redirect_back_or_default redirect_url
#    else
#      render :action => 'new'
#    end
#  end
#
#  def edit
#  end
#
#  def update
#  end
#
#  def destroy
#  end

  protected
    def scoper
      current_account.products
    end
end
