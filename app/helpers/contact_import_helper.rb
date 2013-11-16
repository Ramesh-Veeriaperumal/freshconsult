module ContactImportHelper
   def to_hash(rowarray)
    array_hash = rowarray.each_with_index.map { |x,i| [x,i] }
    return array_hash
   end
end