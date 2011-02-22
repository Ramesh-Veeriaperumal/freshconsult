module ContactImportHelper
   def to_hash(rowarray)
    array_hash = ([nil] + rowarray).inject([]){ |o, e| o << [e,o.size-1]}
    array_hash[0] = [nil,rowarray.size]
    return array_hash
   end
end