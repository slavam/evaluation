class Commerce < ActiveRecord::Base
  establish_connection :plan_fact
  self.abstract_class = true
end