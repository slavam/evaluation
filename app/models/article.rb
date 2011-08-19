class Article < ActiveRecord::Base
  belongs_to :action
  belongs_to :factor
end