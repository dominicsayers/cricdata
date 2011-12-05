require 'net/http'
require "#{Rails.root}/app/helpers/console_log"
require "#{Rails.root}/app/helpers/fetch"

include ConsoleLog
include Fetch

namespace :migrate do
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
