#Module for common utility API methods (DRY...)
module APIHelperMethods

    def convert_query_to_conditions(query_str)
      matches = query_str.split(/((\S+)\s*(is|like)\s*("([^\\"]|\\"|\\\\)*"|(\S+))\s*(or|and)?\s*)/)
      if matches.size > 1
        conditions = []; c_i=0
        matches.size.times{|i| 
          pos = i%7
          conditions[0] = "#{conditions[0]}#{matches[i]} " if(pos == 2) # property
          if(pos == 3) # operator
            oper = matches[i] == "is" ? "=" : matches[i]
            conditions[0] = "#{conditions[0]}#{oper} "
          end
          if(pos == 4) # match value
            conditions[0] = "#{conditions[0]}? "
            matches[i] = matches[i][1..-1] if matches[i][0] == 34 # remove opening double quote
            matches[i] = matches[i][0..-2] if matches[i][-1] == 34 # remove closing double quote
            matches[i] = matches[i].gsub("\\\\", "\\") # remove escape chars
            matches[i] = matches[i].gsub("\\\"", "\"") # remove escape chars
            matches[i] = "%#{matches[i]}%" if matches[i-1] == "like"
            conditions[c_i+=1] = matches[i]
          end
          conditions[0] = "#{conditions[0]}#{matches[i]} " if(pos == 6) # condition and/or
        }
        conditions
      else
        raise "Not able to parse the query."
      end
    end

end