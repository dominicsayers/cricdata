# frozen_string_literal: true

class Inning
  include Mongoid::Document

  # Fields
  field :inning_number,   type: Integer
  field :extras,          type: Integer
  field :extras_analysis, type: String
  field :summary,         type: String
  field :batting_team,    type: String
  field :bowling_team,    type: String

  #  key :match_id, :inning_number
  index({ match_id: 1, inning_number: 1 }, { unique: true })

  # Validations

  # Scopes

  # Relationships
  belongs_to :match
  has_many :performances, dependent: :restrict_with_exception

  # Helpers
  def to_s
    "Match: #{match}, inning number: #{inning_number}, summary: #{summary}"
  end
end
