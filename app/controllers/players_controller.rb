class PlayersController < ApplicationController
  include ConsoleLog

  # GET /players/1
  # GET /players/1.json
  def show
dp params # debug
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

      if /\d+/.match @slug
        players = Player.where(master_ref: @slug)
      else
        players = Player.where(slug: @slug)
        players = Player.where(slug: /^#{@slug}/) if players.length == 0
      end

      case players.length
      when 0
        @message = {:error => 'No matching players'}

        respond_to do |format|
          format.html { render 'empty' }
          format.json { render json: @message }
        end
      when 1
        @player = players.first

        respond_to do |format|
          format.html # show.html.erb
          format.json { render json: @player }
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

  # GET /players/test/xfactor
  # GET /players/test/xfactor.json
	def xfactor
dp params # debug
    match_types = MatchType.where(name: /#{params[:match_type_name]}/i)

    if match_types.length == 0
      respond_to do |format|
        format.html { render 'match_types/unrecognised' }
      end
    else
      type_number = match_types.first.type_number
      @rubric     = {}

      case type_number
      when MatchType::TEST
        @rubric = {
          title:        'test matches',
          clarification:'Post-war all-rounders in test matches',
          qualification:'Qualification: 500 runs at better than 30 and 50 wickets at better than 35',
          xfactor:      'X-factor: Batting ave. over 30 + bowling ave. under 35 + catches per match'
        }
      when MatchType::ODI
        @rubric = {
          title:        'one-day internationals',
          clarification:'All-rounders in one-day internationals',
          qualification:'Qualification: 500 runs at better than 20 and 50 wickets',
          xfactor:      'X-factor: Runs/100 balls (batting - bowling) + balls/wicket (batting - bowling) + catches per match'
        }
      when MatchType::T20I
        @rubric = {
          title:        'Twenty20 internationals',
          clarification:'All-rounders in Twenty20 internationals',
          qualification:'Qualification: 150 runs at better than 10 and 15 wickets',
          xfactor:      'X-factor: Runs/100 balls (batting - bowling) + balls/wicket (batting - bowling) + catches per match'
        }
      end

			@mtps = MatchTypePlayer.xfactory.where(type_number: type_number)

			respond_to do |format|
				format.html { render 'match_type_players/xfactor'}
				format.json { render json: @mtps }
			end
    end
	end
end
