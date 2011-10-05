class Article < ActiveRecord::Base
  belongs_to :action
  belongs_to :factor
  belongs_to :select_type
end