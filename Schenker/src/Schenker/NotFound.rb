class Schenker::NotFound
  require 'any/moose'
  %x{
  BEGIN { extends 'Schenker::Error' }
  }
  %x'no Any::Moose;'
  self.meta.make_immutable
end
