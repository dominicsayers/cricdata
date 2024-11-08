# frozen_string_literal: true

class MatchType
  include Mongoid::Document

  NONE  = 0 # Will never be used as a type_number
  TEST  = 1
  ODI   = 2
  T20I  = 3

  # Fields
  field :type_number, type: Integer
  field :name,        type: String

  #  key :type_number
  index({ type_number: 1 }, { unique: true })

  # Validations

  # Scopes

  # Relationships
  has_many :matches, dependent: :restrict_with_exception

  def self.from_slug(slug)
    case slug
    when 'test' then MatchType.find_by(type_number: TEST)
    when 'odi' then MatchType.find_by(type_number: ODI)
    when 't20i' then MatchType.find_by(type_number: T20I)
    end
  end
end
