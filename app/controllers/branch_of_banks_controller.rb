# coding: utf-8
class BranchOfBanksController < ApplicationController
  def index
    @branches = BranchOfBank.where('open_date is not null').order(:parent_id, :code)    
    
#    @branches = BranchOfBank.find_by_sql("select p.id id, p.code code, p.name name, d.name parent 
#      from fin.division d, fin.division p
#      join FIN.division p on d.id = p.parent_id 
#      where (d.id = p.parent_id and p.open_date is not null) and d.id = 1 order by d.code, p.code")    
  end
end