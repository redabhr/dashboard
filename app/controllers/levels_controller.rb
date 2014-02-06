class LevelsController < ApplicationController
  before_filter :authenticate_user!
  skip_before_filter :verify_authenticity_token, :only => [:builder, :create_custom]
  check_authorization :except => [:builder, :create_custom]
  load_and_authorize_resource :except => [:builder, :create_custom]

  before_action :set_level, only: [:show, :edit, :update, :destroy]

  # GET /levels
  # GET /levels.json
  def index
    @game = Game.find(params[:game_id])
    @levels = @game.levels
  end

  # GET /levels/1
  # GET /levels/1.json
  def show
    @full_width = true
  end

  # GET /levels/new
  def new
    @level = Level.new
    @game = Game.find(params[:game_id])
  end

  # GET /levels/1/edit
  def edit
  end

  # POST /levels
  # POST /levels.json
  def create
    @level = Level.new(level_params.permit([:name, :token, :level_type]))
    @level.game = Game.find(params[:game_id])

    respond_to do |format|
      if @level.save
        format.html { redirect_to [@level.game, @level], notice: I18n.t('crud.created', model: Level.model_name.human) }
        format.json { render action: 'show', status: :created, location: @level }
      else
        format.html { render action: 'new' }
        format.json { render json: @level.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /levels/1
  # PATCH/PUT /levels/1.json
  def update
    respond_to do |format|
      if @level.update(level_params)
        format.html { redirect_to [@level.game, @level], notice: I18n.t('crud.updated', Level.model_name.human) }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @level.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /levels/1
  # DELETE /levels/1.json
  def destroy
    @level.destroy
    respond_to do |format|
      format.html { redirect_to game_levels_url }
      format.json { head :no_content }
    end
  end

  def builder
    @level = Level.find_by_level_num('builder')
    @game = @level.game
    @full_width = true
    @callback = "/create_custom"
    render :show
  end

  def create_custom
    game = Game.find_by_name("Custom")
    @level = Level.new(:game => game, :name => "builder", :solution => params[:program])

    respond_to do |format|
      if @level.save
        format.html { redirect_to [@level.game, @level], notice: I18n.t('crud.created', model: Level.model_name.human) }
        format.json { render action: 'show', status: :created, location: @level }
      else
        format.html { render action: 'new' }
        format.json { render json: @level.errors, status: :unprocessable_entity }
      end
    end
  end


  private
    # Use callbacks to share common setup or constraints between actions.
    def set_level
      @level = Level.find(params[:id])
      @game = @level.game || Game.find(params[:game_id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def level_params
      params[:level].permit([:name, :level_url, :level_num, :skin, {concept_ids: []}])
    end
end
