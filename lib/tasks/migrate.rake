# frozen_string_literal: true

require 'net/http'
require 'mongo'
require Rails.root.join('app/utilities/console_log').to_s
require Rails.root.join('app/utilities/fetch').to_s

include ConsoleLog
include Fetch
include Mongo

namespace :migrate do
  namespace :v3 do
    desc 'This task is run to upgrade the schema from v3 to v4'
    task performances: :environment do
      $\ = ' '

      #			Performance.where(:player_id.exists => false).each do |pf|
      Performance.where(:runs.exists => true).find_each do |pf|
        # Update performance player
        dprint pf.inning_id
        dprint pf.name
        dprint pf.match_type_player_id
        player = pf.match_type_player.player
        dprint player.slug, :white
        pf.player = player
        pf.save

        # Batting performance? Update latest individual score
        if pf.runs.present?
          dprint pf.runs
          score = IndividualScore.where(type_number: pf.type_number, runs: pf.runs).first

          # Is this a later (or the last) performance of this score?
          if score.latest_date.blank? || (pf.date_start > score.latest_date)
            dprint pf.date_start, :cyan
            score.latest_name  = pf.name
            score.latest_date  = pf.date_start
            score.save
          else
            dprint pf.date_start, :green
          end
        end

        puts ''
      end
    end

    task frequencies: :environment do
      $\ = ' '

      # Zero the frequency counters
      IndividualScore.find_each do |score|
        dprint score._id
        score.frequency = 0
        score.notouts = 0
        score.save
      end

      Performance.where(:runs.exists => true).find_each do |pf|
        # Update performance player
        dprint pf.inning_id
        dprint pf.name

        # Batting performance? Update latest individual score
        if pf.runs.present?
          dprint pf.runs
          score = IndividualScore.where(type_number: pf.type_number, runs: pf.runs).first

          if (score.latest_date == pf.date_start) && (score.latest_name == pf.name)
            score.latest_player_id = pf.player_id
            dprint score.latest_player_id, :green
          end

          # Update counts
          score.frequency = score.frequency.blank? ? 1 : score.frequency + 1
          score.notouts	= (score.notouts.blank? ? 1 : score.notouts + 1) if pf.notout
          dprint score.frequency, :white
          dprint score.notouts, :cyan
          score.save
        end

        puts ''
      end
    end
  end

  namespace :v2 do
    desc 'This task is run to upgrade the schema from v2 to v3'
    task fix_performances: :environment do
      $\ = ' '

      old_match_ref = 0

      Performance.where(:match_type_player_id.exists => false).asc(:inning_id).each do |pf|
        match_ref = pf.inning.match_id

        if match_ref == old_match_ref
          dputs match_ref, :pink
        else
          old_match_ref = match_ref
          dputs match_ref
          Match.parse match_ref
        end
      end
    end

    # then
    # rake regular:update_dirty_players RAILS_ENV=test
    # db.performances.remove({match_type_player_id:{$exists:false}})

    task performances: :environment do
      dputs 'Migrating...'

      $\ = ' '

      # Add match type, start date and player's name to performances
      # rake db:mongoid:create_indexes RAILS_ENV=test

      Performance.where(:runs.exists => true, :type_number.exists => false).find_each do |pf|
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
        pf.name	= player.name
        pf.save
      end
    end

    task scores: :environment do
      $\ = ' '

      # rake db:mongoid:create_indexes RAILS_ENV=test

      IndividualScore.destroy_all

      # Seed the benchmark scores
      (1..3).each do |type_number|
        score	= IndividualScore.find_or_create_by type_number: type_number, runs: 0
        score.unscored                  = true
        score.current_lowest_unscored   = true
        score.has_been_lowest_unscored  = true
        score.save
      end

      # Using mongo gem directly because of the size of the result set
      case ENV.fetch('RAILS_ENV', nil)
      when 'test'
        hostname	= 'burdett.moo.li'
        db_name		= 'cricdata'
      when 'production'
        hostname	= 'localhost'
        db_name		= 'cricdata'
      else
        hostname	= 'localhost'
        db_name		= 'cricdata_development'
      end

      db 			= Connection.new(hostname).db db_name
      pfs			= db.collection 'performances'

      pfs.find(runs: { '$ne' => nil }).sort([[:type_number, Mongo::ASCENDING], [:date_start, Mongo::ASCENDING],
                                             [:runs, Mongo::ASCENDING]]).each do |pf|
        dprint pf['type_number']
        dprint pf['date_start']
        dprint pf['runs']
        dprint pf['name']

        inning = Inning.find pf['inning_id']
        mtp = MatchTypePlayer.find pf['match_type_player_id']
        IndividualScore.register inning, mtp, pf['runs'], pf['date_start']
        dputs ' '
      end
    end
  end

  namespace :v1 do
    desc 'This task is run to upgrade the schema from v1 to v2'
    task default: :environment do
      dputs 'Migrating...'

      $\ = ' '

      # Rename player_id to match_type_player_id in performances:
      # mongo --host 21w.moo.li/cricdata
      # 	db.performances.dropIndex("inning_id_1_player_id_1")
      # 	db.performances.dropIndex("player_id_1_inning_id_1")
      # 	db.performances.update({},{$rename:{"player_id":"match_type_player_id"}},false,true)
      # rake db:mongoid:create_indexes RAILS_ENV=test

      # Reparse all T20I matches
      Match.where(match_type_id: '3').update_all(parsed: false)
      Match.parse_all

      # Re-update all mtps to add full name and correct T20I stats
      # Also adds Player documents
      MatchTypePlayer.update_all(dirty: true)
      MatchTypePlayer.update_dirty_players
    end
  end

  namespace :v0 do
    desc 'This task is run to upgrade the schema from v0 to v1'
    task default: :environment do
      dputs 'Migrating...'

      $\ = ' '

      # Innings
      # No innings migration necessary

      # Settings
      # No settings migration necessary

      # Performances
      dputs 'Performances', :white

      Performance.find(:all, conditions: { match_type_player_id: /^.[0-9].+/i }).each do |pf|
        inning	= pf.inning
        match	= inning.match

        dprint pf._id, :cyan

        hsh	= ActiveSupport::JSON.decode(pf.to_json)
        hsh.delete '_id'

        pf2	= Performance.new(hsh)
        pf2.match_type_player_id	= "#{match.match_type_id}-#{pf.match_type_player_id}"
        pf2.save

        dprint pf2._id

        pf.destroy
      end

      dputs "\r\nend\r\n", :white

      # Players
      dputs 'MatchTypePlayers', :white

      MatchTypePlayer.where(:match_type_player_id.exists => true).find_each do |mtp|
        mtp.player_ref = mtp._id
        dprint mtp.name, :cyan

        MatchType.find_each do |match_type|
          new_mtp	= MatchTypePlayer.find_or_create_by type_number: match_type.type_number, player_ref: mtp._id
          new_mtp.name		= mtp.name
          new_mtp.dirty	= mtp.dirty
          new_mtp.save
        end

        mtp.destroy
      end

      dputs "\r\nend\r\n", :white

      # Matches
      dputs 'Matches', :white

      Match.find_each do |match|
        match.match_ref = match._id
        match.unset :match_id
        dprint match.match_ref, :cyan
        match.save
      end

      dputs "\r\nend\r\n", :white

      # Raw matches
      dputs 'Raw matches', :white

      RawMatch.find_each do |raw_match|
        raw_match.match_ref = raw_match._id
        raw_match.unset :match_id
        dprint raw_match.match_ref, :cyan
        raw_match.save
      end

      dputs "\r\nend\r\n", :white

      # Grounds
      dputs 'Grounds', :white

      Ground.find_each do |ground|
        ground.ground_ref = ground._id
        ground.unset :ground_id
        dprint ground.ground_ref, :cyan
        ground.save
      end

      dputs "\r\nend\r\n", :white

      # Match types
      dputs 'Match types', :white

      MatchType.find_each do |match_type|
        match_type.type_number = match_type._id
        match_type.unset :type_id
        dprint match_type.name, :cyan
        match_type.save
      end

      dputs "\r\nend\r\n", :white

      dputs 'done.'
    end

    desc "Add dates for all matches that don't have them"
    task match_dates: :environment do
      $\ = ' '
      $, = '/'

      Match.where(:date_end.exists => false).find_each do |match|
        # -dprint '+', :cyan # debug
        match_ref = match.match_ref
        dprint match_ref
        # Get match data
        raw_match = RawMatch.find_or_create_by(match_ref: match_ref)

        if raw_match.zhtml.blank?
          url = 'http://www.espncricinfo.com/ci/engine/match/%s.json?view=scorecard' % match_ref
          raw_match.zhtml = BSON::Binary.new(Zlib::Deflate.deflate(get_response(url)))
          raw_match.save
        end

        doc = Nokogiri::HTML(Zlib::Inflate.inflate(raw_match.zhtml.to_s))

        # Parse dates
        title = doc.xpath('//title').first.children.first.content
        /.+?,\s(\w{3})\s([0-9]{1,2})(?:,\s([0-9]+))*(?:\s*(?:-)*\s*(\w{3})*\s*([0-9]{1,2}),\s([0-9]+))*/i.match(title)
        # -dp Regexp.last_match(0), :pink # debug
        m1 = Regexp.last_match(1)
        d1 = Regexp.last_match(2)
        y1 = Regexp.last_match(3)
        m2 = Regexp.last_match(4)
        d2 = Regexp.last_match(5)
        y2 = Regexp.last_match(6)

        y1 = y2 if y1.blank?
        m2 = m1 if m2.blank?
        d2 = d1 if d2.blank?
        y2 = y1 if y2.blank?

        m1n = Date::ABBR_MONTHNAMES.index(m1)
        m2n = Date::ABBR_MONTHNAMES.index(m2)
        match.date_start  = Date.new(y1.to_i, m1n, d1.to_i)
        match.date_end    = Date.new(y2.to_i, m2n, d2.to_i)
        match.save
        # -print y1,m1,d1,' ',y2,m2,d2 # debug
      end
    end

    desc 'Compress the cached HTML'
    task deflate_raw_matches: :environment do
      $\ = ' '

      RawMatch.where(:html.exists => true).find_each do |raw_match|
        zhtml = Zlib::Deflate.deflate(raw_match.html)
        # -dputs "#{raw_match._id} #{raw_match.html.length} #{zhtml.length}" # debug
        raw_match.zhtml = BSON::Binary.new(zhtml)
        raw_match.unset :html
        raw_match.save
      end
    end
  end
end
