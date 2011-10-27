# coding: utf-8
class WorkersController < ApplicationController
  before_filter :find_worker, :only => [:my_show, :edit, :update, :destroy]
  def index
    @workers = Worker.select([:id_emp, :tabn, :id_division, :lastname, :firstname, :soname]).order(:id_emp).paginate :page => params[:page], :per_page => 20
  end
  
  def my_show
  end

  def new
    @worker = Worker.new
  end
  
  def create
    @worker = Worker.new params[:worker]
    if not @worker.save
      render :new
    else
      redirect_to :workers
    end
  end
  
  private
  def find_worker
    @workers = Worker.select([:id_emp, :tabn, :id_division, :lastname, :firstname, :soname]).where("id_emp=?", params[:id])
    @worker = @workers[0]
  end
=begin
  MSB
select * from emp2doc e 
join div2doc d on d.id_division = e.id_division
join div2doc p on p.id_division = d.parent_id
where e.id_division = 56922 or e.code_division like '%8000' order by p.code_division
=end  
end
