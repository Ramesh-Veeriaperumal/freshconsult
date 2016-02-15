class Fdadmin::FreshfoneStats::PhoneNumberController < Fdadmin::DevopsMainController
  include Fdadmin::FreshfoneStatsMethods
  around_filter :select_slave_shard , :only => [:deleted_freshfone_csv_by_account,:all_freshfone_number_csv]

  def phone_statistics
    phone_number_stats = {}
    phone_number_stats[:total_ff] = find_total_freshfone(Sharding.run_on_all_slaves { ActiveRecord::Base.connection.execute(total_freshfone_numbers) })
    respond_to do |format|
      format.json do
        render :json => phone_number_stats
      end
    end
  end

  def deleted_freshfone_csv_by_account
    params.merge!(:export_type => "Deleted and ported numbers for Account :: #{params["account_id"]}")
    deleted_ff_conditions = ['deleted = ?',true]
    deleted_numbers = account.all_freshfone_numbers.where(deleted_ff_conditions)
    deleted_numbers_list = single_account_deleted_freshfone(deleted_numbers)
    generate_email(deleted_numbers_list, deleted_ff_csv_columns)
  end

  def deleted_freshfone_csv
    params.merge!(:export_type => "Deleted and ported numbers")
    deleted_ff_query = freshfone_numbers_deleted_in_date_range(params[:startDate], params[:endDate])
    deleted_ff_list = cumulative_result(Sharding.run_on_all_slaves {ActiveRecord::Base.connection.execute(deleted_ff_query)})
    generate_email(deleted_ff_list, all_deleted_ff_csv_columns)
  end

  def all_freshfone_number_csv
    params.merge!(:export_type => "numbers for Account :: #{params["account_id"]}")
    all_freshfone_numbers = account.freshfone_numbers
    freshfone_numbers_list = all_freshfone_numbers_list(all_freshfone_numbers)
    generate_email(freshfone_numbers_list, ff_csv_columns)
  end

  private

    def total_freshfone_numbers
      "SELECT count(*) AS 'count' FROM freshfone_numbers
      WHERE freshfone_numbers.deleted = FALSE"
    end

    def freshfone_numbers_deleted_in_date_range(start_date,end_date)
      "SELECT accounts.id, accounts.name, count(freshfone_numbers.number) - count(port), count(port)
      FROM freshfone_numbers JOIN accounts
      ON freshfone_numbers.account_id = accounts.id
      WHERE freshfone_numbers.deleted = TRUE
      AND freshfone_numbers.updated_at >= '" +start_date+ "' AND freshfone_numbers.updated_at <= '"+end_date+"'
      GROUP BY accounts.id DESC"
    end

    def find_total_freshfone(resultset, total = 0)
      resultset.each do |results|
        results.each do |result|
          result.each do |count|
            total += count
          end
        end
      end
      total
    end

    def single_account_deleted_freshfone(list, ff_list=[])
      list.each do |ff|
        ff_list << [account.id,
                    account.name,
                    ff.number,
                    ff.updated_at,
                    ff.port ==  Freshfone::Number::PORT_STATE[:port_away] ? "Port away" : "Deleted"]
      end
      ff_list
    end

    def all_freshfone_numbers_list(list, ff_numbers=[])
      list.each do |ff|
        ff_numbers << [ ff.id,
                        ff.account_id,
                        ff.number,
                        ff.display_number,
                        ff.country,
                        ff.region,
                        ff.state ==  Freshfone::Number::STATE[:active] ? "Active" : "Expired" ,
                        ff.next_renewal_at,
                        ff.created_at ]
      end
      ff_numbers
    end

    def deleted_ff_csv_columns
      ["Account ID", "Account Name", "Freshfone Number", "Time", "Status"]
    end

    def all_deleted_ff_csv_columns
      ["Account ID", "Account Name", "Freshfone Number Count", "Port Away Count"]
    end

    def ff_csv_columns
      ["Number ID", "Account ID", "Number", "Display Number", "Country", "Region", "State", "Next Renewal", "Created At"]
    end

end

