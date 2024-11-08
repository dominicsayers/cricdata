# frozen_string_literal: true

class IndividualScoresController < ApplicationController
  include ConsoleLog

  before_action :parse_match_type

  def parse_match_type
    match_types = MatchType.where(name: /#{params[:match_type_name]}/i)

    if match_types.empty?
      respond_to do |format|
        format.html { render 'match_types/unrecognised' }
      end
    else
      @type_number = match_types.first.type_number
    end
  end

  # GET /:match_type_name/scores/individual
  # GET /:match_type_name/scores/individual.json
  def index
    @individual_scores = IndividualScore.where(type_number: @type_number).all

    @rubric = {}

    case @type_number
    when MatchType::TEST
      @rubric = {
        title: 'test matches',
        clarification: 'Individual scores in test matches'
      }
    when MatchType::ODI
      @rubric = {
        title: 'one-day internationals',
        clarification: 'Individual scores in one-day internationals'
      }
    when MatchType::T20I
      @rubric = {
        title: 'Twenty20 internationals',
        clarification: 'Individual scores in Twenty20 internationals'
      }
    end

    @rubric[:match_type_name] = params[:match_type_name]
    dputs params
    dputs @rubric

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @individual_scores }
    end
  end

  # GET /:match_type_name/scores/individual/1
  # GET /:match_type_name/scores/individual/1.json
  def show
    @performances = Performance.batting.where(type_number: @type_number, runs: params[:id]).asc :date_start

    @rubric = {}

    case @type_number
    when MatchType::TEST
      @rubric = {
        title: 'test matches',
        clarification: 'The history of a particular score in test matches'
      }
    when MatchType::ODI
      @rubric = {
        title: 'one-day internationals',
        clarification: 'The history of a particular score in one-day internationals'
      }
    when MatchType::T20I
      @rubric = {
        title: 'Twenty20 internationals',
        clarification: 'The history of a particular score in Twenty20 internationals'
      }
    end

    @rubric[:match_type_name] = params[:match_type_name]
    dputs params
    dputs @rubric

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @performances }
    end
  end
end
