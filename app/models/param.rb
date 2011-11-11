class Param < ActiveRecord::Base
  belongs_to :param_description
  belongs_to :factor
  belongs_to :action
end