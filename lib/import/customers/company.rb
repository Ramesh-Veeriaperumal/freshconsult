class Import::Customers::Company < Import::Customers::Base

  def initialize(params={})
    super params
  end

  def default_validations
    item_param = @params_hash[:"#{@type}"]
    item_param[:name].blank? ? return : load_item 
  end

  def create_imported_company
    @item.attributes = @params_hash[:company]
    @item.save
  end

  private

  def load_item
    @params_hash[:company][:name] = @params_hash[:company][:name].to_s.strip.split(COMPANY_DELIMITER)[0].squish.gsub(/&amp;/, AND_SYMBOL)
    @item = current_account.companies.find_by_name(@params_hash[:company][:name])
  end
end