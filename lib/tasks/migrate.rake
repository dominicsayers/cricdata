require 'net/http'
require 'mongo'
require "#{Rails.root}/app/helpers/console_log"
require "#{Rails.root}/app/helpers/fetch"

include ConsoleLog
include Fetch
include Mongo

namespace :migrate do
	namespace :v2 do
		desc "This task is run to upgrade the schema from v2 to v3"
		task :fix_performances => :environment do
			$\ = ' '

			old_match_ref = 0

			Performance.where(:match_type_player_id.exists => false).asc(:inning_id).each do |pf|
				match_ref = pf.inning.match_id

				if match_ref != old_match_ref
					old_match_ref = match_ref
	dputs match_ref
					Match.parse match_ref
				else
					dputs match_ref, :pink # debug
				end
			end
		end

		# then
		# rake regular:update_dirty_players RAILS_ENV=test
		# db.performances.remove({match_type_player_id:{$exists:false}})

		task :performances => :environment do
			dputs 'Migrating...'

			$\ = ' '

			# Add match type, start date and player's name to performances
			# rake db:mongoid:create_indexes RAILS_ENV=test

			Performance.where(:runs.exists => true, :type_number.exists => false).each do |pf|
				dprint pf.type_number, :red
				dprint pf.runs
				dprint pf.inning_id
				inning = Inning.find pf.inning_id
				dprint inning.match_id
				match = Match.find inning.match_id
				dprint match.date_start
				dprint pf.match_type_player_id
				player = MatchTypePlayer.find pf.match_type_player_id
				dprint player.name
				dputs player.type_number

				pf.type_number	= player.type_number
				pf.date_start		= match.date_start
				pf.name					= player.name
				pf.save
			end
		end

		task :scores => :environment do
			$\ = ' '

			# rake db:mongoid:create_indexes RAILS_ENV=test

			IndividualScore.destroy_all

			# Seed the benchmark scores
			for type_number in 1..3
				in_sc														= IndividualScore.find_or_create_by type_number:type_number, runs:0
				in_sc.unscored                  = true
				in_sc.current_lowest_unscored   = true
				in_sc.has_been_lowest_unscored  = true
				in_sc.save
			end

			type_number	= MatchType::NONE
			runs				= -1

			# Using mongo gem directly because of the size of the result set
	    db_name	= [ 'test', 'production' ].include?(ENV['RAILS_ENV']) ? 'cricdata' : 'cricdata_development'
			db 			= Connection.new.db db_name
			pfs			= db.collection('performances')

			pfs.find(:runs => {'$ne' => nil}).sort( [ [:type_number, Mongo::ASCENDING], [:date_start, Mongo::ASCENDING], [:runs, Mongo::ASCENDING] ] ).each do |pf|
				dprint pf['type_number']
				dprint pf['date_start']
				dprint pf['runs']
				dprint pf['name']

				IndividualScore.register pf['type_number'], pf['runs'], pf['date_start'], pf['name']
	dputs ' ' # debug
			end
		end
	end

	namespace :v1 do
		desc "This task is run to upgrade the schema from v1 to v2"
		task :default => :environment do
			dputs 'Migrating...'

			$\ = ' '

			# Rename player_id to match_type_player_id in performances:
			# mongo --host 21w.moo.li/cricdata
			# 	db.performances.dropIndex("inning_id_1_player_id_1")
			# 	db.performances.dropIndex("player_id_1_inning_id_1")
			# 	db.performances.update({},{$rename:{"player_id":"match_type_player_id"}},false,true)
			# rake db:mongoid:create_indexes RAILS_ENV=test

			# Reparse all T20I matches
			Match.where(match_type_id:"3").update_all(parsed:false)
			Match.parse_all

			# Re-update all mtps to add full name and correct T20I stats
			# Also adds Player documents
			MatchTypePlayer.all.update_all(dirty:true)
			MatchTypePlayer.update_dirty_players
		end
	end

	namespace :v0 do
		desc "This task is run to upgrade the schema from v0 to v1"
		task :default => :environment do
			dputs 'Migrating...'

			$\ = ' '

			# Innings
			# No innings migration necessary

			# Settings
			# No settings migration necessary

			# Performances
			dputs 'Performances', :white

			Performance.find(:all, :conditions => {:match_type_player_id => /^.[0-9].+/i}).each do |pf|
				inning			= pf.inning
				match 			= inning.match

				dprint pf._id, :cyan

				hsh						= ActiveSupport::JSON.decode(pf.to_json)
				hsh.delete '_id'

				pf2						= Performance.new(hsh)
				pf2.match_type_player_id	= "#{match.match_type_id}-#{pf.match_type_player_id}"
				pf2.save

				dprint pf2._id

				pf.destroy
			end

			dputs "\r\nend\r\n", :white

			# Players
			dputs 'MatchTypePlayers', :white

			MatchTypePlayer.where(:match_type_player_id.exists => true).each do |mtp|
				mtp.player_ref = mtp._id
				dprint mtp.name, :cyan

				MatchType.all.each do |match_type|
					new_mtp				= MatchTypePlayer.find_or_create_by type_number:match_type.type_number, player_ref:mtp._id
					new_mtp.name		= mtp.name
					new_mtp.dirty	= mtp.dirty
					new_mtp.save
				end

				mtp.destroy
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

			dputs "\r\nend\r\n", :white

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

		desc "Add dates for all matches that don't have them"
		task :match_dates => :environment do
				$\ = ' '
				$, = '/'

			Match.where(:date_end.exists => false).each do |match|
		#-dprint '+', :cyan # debug
				match_ref   = match.match_ref
		dprint match_ref # debug
				# Get match data
				raw_match   = RawMatch.find_or_create_by(match_ref: match_ref)

				if raw_match.zhtml.blank?
					url             = 'http://www.espncricinfo.com/ci/engine/match/%s.json?view=scorecard' % match_ref
					raw_match.zhtml  = BSON::Binary.new(Zlib::Deflate.deflate(get_response(url)))
					raw_match.save
				end

				doc = Nokogiri::HTML(Zlib::Inflate.inflate(raw_match.zhtml.to_s))

				# Parse dates
				title = doc.xpath("//title").first.children.first.content
				/.+?,\s(\w{3})\s([0-9]{1,2})(?:,\s([0-9]+))*(?:\s*(?:-)*\s*(\w{3})*\s*([0-9]{1,2}),\s([0-9]+))*/i.match(title)
		dp $&, :pink # debug
				m1 = $1
				d1 = $2
				y1 = $3
				m2 = $4
				d2 = $5
				y2 = $6

				y1 = y2 if y1.blank?
				m2 = m1 if m2.blank?
				d2 = d1 if d2.blank?
				y2 = y1 if y2.blank?

				m1n = Date::ABBR_MONTHNAMES.index(m1)
				m2n = Date::ABBR_MONTHNAMES.index(m2)
				match.date_start  = Date.new(y1.to_i, m1n, d1.to_i)
				match.date_end    = Date.new(y2.to_i, m2n, d2.to_i)
				match.save
		#-print y1,m1,d1,' ',y2,m2,d2 # debug
			end
		end

		desc "Compress the cached HTML"
		task :deflate_raw_matches => :environment do
				$\ = ' '

			RawMatch.where(:html.exists => true).each do |raw_match|
				zhtml = Zlib::Deflate.deflate(raw_match.html)
		dputs "#{raw_match._id} #{raw_match.html.length} #{zhtml.length}" # debug
				raw_match.zhtml = BSON::Binary.new(zhtml)
				raw_match.unset :html
				raw_match.save
			end
		end
	end
end
