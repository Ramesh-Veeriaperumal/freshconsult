class Companies::MiscController < ApiApplicationController
  include HelperConcern
  include ContactsCompaniesConcern
  include Export::Util

  before_filter :export_limit_reached?, only: [:export]
  before_filter :load_data_export, only: [:export_details]

  EXPORT_TYPE = 'company'.freeze

  def export
    contact_company_export(EXPORT_TYPE)
  end

  def export_details
    fetch_export_details
  end

  private

    def scoper
      current_account.companies
    end

    def load_objects(filter = nil)
      # preload(:flexifield, :company_domains) will avoid n + 1 query to company field data & company domains
      super (filter || scoper).preload(preload_options).order(:name)
    end

    def preload_options
      [:flexifield, :company_domains]
    end

    def constants_class
      :CompanyConstants.to_s.freeze
    end

    def load_data_export
      fetch_data_export_item EXPORT_TYPE
    end

    def export_limit_reached?
      check_export_limit EXPORT_TYPE
    end
end
