# frozen_string_literal: true

class Player
  include Mongoid::Document

  # Fields
  field :slug,        type: String
  field :name,        type: String
  field :fullname,    type: String
  field :master_ref,  type: Integer
  field :player_refs, type: Array # If there's more than one, this is a disambiguation page

  #  field :_id,         :type => String, default: ->{ slug }

  index({ slug: 1 }, { unique: true })
  index({ master_ref: 1 })
  index({ player_refs: 1 })

  # Validations

  # Scopes

  # Relationships
  has_many :match_type_players, dependent: :restrict_with_exception
  has_many :performances, dependent: :restrict_with_exception

  # Helpers
end
