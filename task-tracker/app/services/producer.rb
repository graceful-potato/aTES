# frozen_string_literal: true

class Producer
  def self.call(event, topic:)
    puts "TOPIC: #{topic}\nEVENT: #{event.to_json}"
  end
end
