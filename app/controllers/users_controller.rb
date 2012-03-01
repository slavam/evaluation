class UsersController < ApplicationController
  before_filter :require_admin
  before_filter :find_user, :only => [ :show, :edit, :update, :destroy ]

  def index
    @users = User.all(:order => :login)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new params[:user]
#    @user.randomize_password

    if not @user.save
      render :new
    else
#      @user.deliver_new_user_instructions!
      notice_created
      redirect_to :users
    end
  end

  def show
  end

  def edit
  end

  def update
    if not @user.update_attributes params[:user]
      render :action => :edit
    else
      notice_updated
      redirect_to user_path(@user)
    end
  end

  def destroy
    @user.destroy
    redirect_to :users
  end

private
  def find_user
    @user = User.find params[:id]  
  end
end
