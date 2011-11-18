require 'net/http'
require "#{Rails.root}/app/helpers/console_log"
require "#{Rails.root}/app/helpers/fetch"

include ConsoleLog
include Fetch

desc "This task is run to upgrade the schema from v0 to v0"

task :play => :environment do
    dputs 'Playing...'

    $\ = ' '

    # Performances
    dputs 'Performances', :white

    Performance.find(:all, :conditions => {:player_id => /^.[0-9].+/i}).each do |pf|
			inning			= pf.inning
			match 			= inning.match

			dprint pf._id, :cyan

			hsh						= ActiveSupport::JSON.decode(pf.to_json)
			hsh.delete '_id'

			pf2						= Performance.new(hsh)
			pf2.player_id	= "#{match.match_type_id}-#{pf.player_id}"
#			pf2.save

			dprint pf2._id

#			pf.destroy
    end

    dputs "\r\nend\r\n", :white
end

task :migrate_v0 => :environment do
    dputs 'Migrating...'

    $\ = ' '

		# Innings
		# No innings migration necessary

		# Settings
		# No settings migration necessary

    # Performances
    dputs 'Performances', :white

    Performance.find(:all, :conditions => {:player_id => /^.[0-9].+/i}).each do |pf|
			inning			= pf.inning
			match 			= inning.match

			dprint pf._id, :cyan

			hsh						= ActiveSupport::JSON.decode(pf.to_json)
			hsh.delete '_id'

			pf2						= Performance.new(hsh)
			pf2.player_id	= "#{match.match_type_id}-#{pf.player_id}"
			pf2.save

			dprint pf2._id

			pf.destroy
    end

    dputs "\r\nend\r\n", :white

    # Players
    dputs 'Players', :white

    Player.where(:player_id.exists => true).each do |player|
      player.player_ref = player._id
      dprint player.name, :cyan

      MatchType.all.each do |match_type|
				new_player				= Player.find_or_create_by type_number:match_type.type_number, player_ref:player._id
				new_player.name		= player.name
				new_player.dirty	= player.dirty
				new_player.save
      end

      player.destroy
    end

    dputs "\r\nend\r\n", :white

    # Matches
    dputs 'Matches', :white

    Match.all.each do |match|
      match.match_ref = match._id
      match.unset :match_id
      dprint match.match_ref, :cyan
      match.save
    end

    dputs "\r\nend\r\n", :white

    # Raw matches
    dputs 'Raw matches', :white

    RawMatch.all.each do |raw_match|
      raw_match.match_ref = raw_match._id
      raw_match.unset :match_id
      dprint raw_match.match_ref, :cyan
      raw_match.save
    end

    # Grounds
    dputs 'Grounds', :white

    Ground.all.each do |ground|
      ground.ground_ref = ground._id
      ground.unset :ground_id
      dprint ground.ground_ref, :cyan
      ground.save
    end

    dputs "\r\nend\r\n", :white

    # Match types
    dputs 'Match types', :white

    MatchType.all.each do |match_type|
			match_type.type_number = match_type._id
			match_type.unset :type_id
			dprint match_type.name, :cyan
    	match_type.save
    end

    dputs "\r\nend\r\n", :white

    dputs 'done.'
end
