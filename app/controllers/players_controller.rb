class PlayersController < ApplicationController
  # GET /players/1
  # GET /players/1.json
  def show
    @slug = params[:id]
    begin
      # Look for player with this id
      @player = Player.find(@slug)

      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @player }
      end
    rescue
      # Couldn't find a matching player, so search by slug
      @player_refs = []

      players = Player.where(slug:@slug)
      players = Player.where(slug:/^#{@slug}/) if players.length == 0

      if players.length == 0
        @message = {:error => 'No matching players'}

        respond_to do |format|
          format.html { render 'empty' }
          format.json { render json: @message }
        end
      else
        players.each do |player|
          @player_refs = @player_refs | player.player_refs
        end

        respond_to do |format|
          format.html { render 'list' }
          format.json { render json: @player_refs }
        end
      end
    end
  end
end
