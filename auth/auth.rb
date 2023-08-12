# frozen_string_literal: true

require "roda"

class Auth < Roda
  plugin :json
  plugin :all_verbs
  plugin :halt

  route do |r|
    r.root do
      { message: "hello" }
    end
  end
end
