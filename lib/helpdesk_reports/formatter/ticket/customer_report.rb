class HelpdeskReports::Formatter::Ticket::CustomerReport
  
  include HelpdeskReports::Util::Ticket
  
  attr_accessor :others, :unresolved

  METRICS = ["agent_interactions","customer_interactions","reopened_tickets",
             "received_tickets","resolved_tickets","response_violated","resolution_violated"]

  PERCENTAGE_METRICS = ["response_violated","resolution_violated"]

  ORDER_BY = ['asc', 'desc']

  MAX_RANK = 10

  def initialize data, args = {}
    @others     = data['CUSTOMER_CURRENT_HISTORIC']
    @unresolved = data['UNRESOLVED_TICKETS']
  end
  
  def perform
    @others     = [] if (@others.is_a?(Hash) && @others["error"]) || @others.empty? #Handling the edge cases
    @unresolved = [] if (@unresolved.is_a?(Hash) && @unresolved["error"]) || @unresolved.empty?
    @output_hash = Hash.new { |hash, key| hash[key] = Hash.new(&hash.default_proc) }
      if @others.present?
        @company_hash = Account.current.companies_from_cache.collect { |au| [au.id, au.name] }.to_h
        @others.each do | row |
          METRICS.each do | metric |
            ORDER_BY.each do | order |
              id    = row["company_id"].to_i
              name  = @company_hash[id]
              value = row["#{metric}"]
              count = row["#{metric}_tickets"].to_i
              value = "0" if PERCENTAGE_METRICS.include?(metric) && value.nil? && count > 0 #Handling 0% violated case
              @output_hash[metric.upcase][:company_id][name] = {id:id,value:value.to_i,tickets_count:count} if row["#{metric}_#{order}"].to_i <= MAX_RANK && !name.nil? && !value.nil?
            end
          end
        end
      end
      @output_hash['UNRESOLVED_TICKETS'][:company_id] = unresolved[:company_id] || {} if @unresolved.present?
    sort_group_by_values
  end

  def sort_group_by_values
    @output_hash.each do |metric, res|
      res.each do |gp_by, values|
        res[gp_by]  = {} 
        values      = values.select{|k,v| k != NOT_APPICABLE }.to_a
        if values.empty?
          res.delete(gp_by)
          next 
        end
        asc_values  = values.sort_by{|i| [ i.second[:value], i.second[:tickets_count], i.first.downcase] }[0..4] 
        des_values  = values.sort_by{|i| [-i.second[:value], i.second[:tickets_count], i.first.downcase] }[0..4] 
        res[gp_by]["ASC"]  = asc_values.to_h
        res[gp_by]["DESC"] = des_values.to_h
      end
    end
  end

end