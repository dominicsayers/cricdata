class PlayersController < ApplicationController
	def xfactor
		@players = Player.xfactory
	end
end
