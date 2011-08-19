# coding: utf-8
class BusinessesController < ApplicationController
  before_filter :find_business, :only => [:show, :edit, :update, :destroy]
  def index
    @businesses = Business.order(:id)
  end
  
  def show
  end

  def new
    @block = Block.new
  end
  
  def create
    @block = Block.new params[:block]
    if not @block.save
      render :new
    else
      redirect_to :blocks
    end
  end
  
  def edit
  end

  def update
    if not @bolck.update_attributes params[:block]
      render :action => :edit
    else
      redirect_to block_path(@block)
    end
  end
  
  def destroy
    @block.destroy
    redirect_to blocks_path
  end
  
  private
  
  def find_business
    if params[:id]
      @business = Business.find params[:id]
    end
  end
end