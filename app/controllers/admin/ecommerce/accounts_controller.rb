class Admin::Ecommerce::AccountsController < Admin::AdminController

  before_filter(:only => [:index]) { |c| c.requires_feature :ecommerce }

  def index
    @ecommerce_accounts = scoper
  end

  private

  def scoper
    current_account.ecommerce_accounts
  end
  
end

