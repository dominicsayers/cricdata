# frozen_string_literal: true

# Raw match HTML from the source
class RawMatch
  include Mongoid::Document

  # Fields
  field :match_ref, type: Integer
  field :match_json, type: String
  field :scorecard_html, type: String

  #  key :match_ref
  index({ match_ref: 1 }, { unique: true })
end
