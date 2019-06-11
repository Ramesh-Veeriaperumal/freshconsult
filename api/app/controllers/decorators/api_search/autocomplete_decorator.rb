class ApiSearch::AutocompleteDecorator < ApiDecorator
  delegate :id, :name, to: :record

  def company_hash
    ret_hash = { id: id }
    private_api? ? ret_hash.merge!(private_company_hash) : ret_hash.merge!(public_company_hash)
    ret_hash
  end

  private

    def private_company_hash
      { value: name }
    end

    def public_company_hash
      { name: name }
    end
end
