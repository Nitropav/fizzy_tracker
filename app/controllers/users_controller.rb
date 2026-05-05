class UsersController < ApplicationController
  wrap_parameters :user, include: %i[ name avatar email_address password password_confirmation role cactus_role ]

  before_action :set_user, except: %i[ index create ]
  before_action :ensure_admin, only: :create
  before_action :ensure_permission_to_change_user, only: %i[ update destroy ]

  def index
    set_page_and_extract_portion_from Current.account.users.active.alphabetically.includes(:identity)
  end

  def show
  end

  def edit
  end

  def create
    @user_creation = Account::UserCreation.new(user_creation_params.with_defaults(account: Current.account))

    if @user_creation.save
      redirect_to account_settings_path, notice: "User created. Share the email and password with them securely."
    else
      @account = Current.account
      @users = @account.users.active.alphabetically.includes(:identity)
      render "account/settings/show", status: :unprocessable_entity
    end
  end

  def update
    if @user.update(user_params)
      respond_to do |format|
        format.html { redirect_to @user }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @user.deactivate

    respond_to do |format|
      format.html { redirect_to account_settings_path }
      format.json { head :no_content }
    end
  end

  private
    def set_user
      @user = Current.account.users.active.find(params[:id])
    end

    def ensure_permission_to_change_user
      head :forbidden unless Current.user.can_change?(@user)
    end

    def user_creation_params
      params.expect(user: %i[ name email_address password password_confirmation role cactus_role ])
    end

    def user_params
      params.expect(user: [ :name, :avatar ])
    end
end
