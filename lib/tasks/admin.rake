require 'net/http'
require "#{Rails.root}/app/helpers/console_log"
require "#{Rails.root}/app/helpers/fetch"

include ConsoleLog
include Fetch

namespace :admin do
  desc "These tasks are run manually for admin purposes"
  task :mark_all_players_dirty => :environment do
      dputs 'Marking all players as dirty...'

      Player.all.each do |player|
        player.dirty = true
  dputs player.inspect # debug
        player.save
      end

      dputs 'done.'
  end

  task :mark_indeterminate_players_dirty => :environment do
      dputs 'Marking all indeterminate players as dirty...'

      Player.indeterminate.each do |player|
        player.dirty = true
  dputs player.inspect # debug
        player.save
      end

      dputs 'done.'
  end

  task :fix_missing_players => :environment do
      dputs 'Finding unknown players who have performances...'

      $\ = ' '

      Performance.all.each do |pf|
        player_id = pf.player_id

        begin
          player = Player.find(player_id)
          dprint '.', :white
        rescue
          type_number, player_ref = player_id.split('-')

          # Get fielding data
          url = 'http://stats.espncricinfo.com/ci/engine/player/%s.json?class=%s;template=results;type=fielding;view=innings' % [player_ref, type_number]
          dputs ''
          doc = get_data url

          dprint player_id, :cyan

          # Name
          name = doc.xpath('//h1[@class="SubnavSitesection"]').first.content.split("/\n")[2].strip
          dprint name, :cyan

          # Full name
          fullname  = ''
          scripts   = doc.xpath('//script')

          scripts.each do |script|
            /var omniPageName.+:(.+)";/i.match(script.content[0..100])

            unless $1.nil?
              fullname = $1
              dputs $1, :cyan
              break
            end
          end

          player          = Player.new(type_number:type_number, player_ref:player_ref)
          player.name     = name
          player.fullname = fullname unless fullname.blank?
          player.dirty    = true
          player.save
        end
      end

      dputs 'done.'
  end

  task :update_player, [:player_ref] => [:environment] do |t, args|
      player_ref = (args.player_ref || "0")
      dputs "Parsing #{player_ref}..."
      Player.update player_ref
      dputs 'done.'
  end

  task :mark_all_matches_unparsed => :environment do
      dputs 'Marking all matches as unparsed...'
      Match.mark_all_unparsed
      dputs 'done.'
  end

  task :parse_match, [:match_ref] => [:environment] do |t, args|
      match_ref = (args.match_ref || "0")
      dputs "Parsing #{match_ref}..."
      Match.parse match_ref
      dputs 'done.'
  end
end
