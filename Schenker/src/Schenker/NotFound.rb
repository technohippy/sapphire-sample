class Schenker::NotFound
  require 'any/moose'

  __BEGIN__ do
    extend Schenker::Error
  end

  %x'no Any::Moose;'
  self.meta.make_immutable
end
