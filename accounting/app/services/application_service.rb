# frozen_string_literal: true

class ApplicationService
  def self.call(*args, **kwargs, &block)
    new.call(*args, **kwargs, &block)
  end
end
