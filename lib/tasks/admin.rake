# frozen_string_literal: true

require 'net/http'
require Rails.root.join('app/helpers/console_log').to_s
require Rails.root.join('app/helpers/fetch').to_s

include ConsoleLog
include Fetch

namespace :admin do
  desc 'These tasks are run manually for admin purposes'
  task mark_all_players_dirty: :environment do
    $\ = ' '

    dputs 'Marking all players as dirty...'
    MatchTypePlayer.update_all(dirty: true)
    dputs 'done.'
  end

  task mark_indeterminate_players_dirty: :environment do
    dputs 'Marking all indeterminate players as dirty...'
    MatchTypePlayer.indeterminate.update_all(dirty: true)
    dputs 'done.'
  end

  task update_xfactor: :environment do
    $\ = ' '

    dputs 'Updating all X-factors...'
    MatchTypePlayer.find_each do |mtp|
      dprint mtp.fullname, :cyan
      MatchTypePlayer.update_xfactor mtp
    end
    dputs 'done.'
  end

  task fix_missing_players: :environment do
    dputs 'Finding unknown players who have performances...'

    $\ = ' '

    Performance.find_each do |pf|
      match_type_player_id = pf.match_type_player_id

      begin
        mtp = MatchTypePlayer.find(match_type_player_id)
        dprint '.', :white
      rescue StandardError
        dprint match_type_player_id, :white

        type_number, player_ref = match_type_player_id.split('-')

        # Get fielding data
        url = format(
          'https://stats.espncricinfo.com/ci/engine/player/%s.json?class=%s;template=results;type=fielding;view=innings', player_ref, type_number
        )
        dputs ''
        doc = get_data url

        # Name
        name = doc.xpath('//h1[@class="SubnavSitesection"]').first.content.split("/\n")[2].strip
        dprint name, :cyan

        # Full name
        fullname  = ''
        scripts   = doc.xpath('//script')

        scripts.each do |script|
          /var omniPageName.+:(.+)";/i.match(script.content[0..100])

          next if Regexp.last_match(1).nil?

          fullname = Regexp.last_match(1)
          dputs Regexp.last_match(1), :cyan
          break
        end

        mtp          = MatchTypePlayer.new(type_number: type_number, player_ref: player_ref)
        mtp.name     = name
        mtp.fullname = fullname if fullname.present?
        mtp.dirty    = true
        mtp.save
      end
    end

    dputs 'done.'
  end

  task :update_player, [:player_ref] => [:environment] do |_t, args|
    player_ref = args.player_ref || '0'
    dputs "Parsing #{player_ref}..."
    MatchTypePlayer.update player_ref
    dputs 'done.'
  end

  task mark_all_matches_unparsed: :environment do
    dputs 'Marking all matches as unparsed...'
    Match.mark_all_unparsed
    dputs 'done.'
  end

  task :parse_match, [:match_ref] => [:environment] do |_t, args|
    match_ref = args.match_ref || '0'
    dputs "Trying to parse match #{match_ref}..."
    Match.parse match_ref
    dputs 'done.'
  end
end
