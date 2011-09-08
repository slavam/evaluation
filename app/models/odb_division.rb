class OdbDivision < ActiveRecord::Base
  establish_connection :odb
  self.abstract_class = true
end
