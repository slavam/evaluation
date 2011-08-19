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
end
