class ProblemRate < ActiveRecord::Base
  belongs_to :direction
  belongs_to :factor
end