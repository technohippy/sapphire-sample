class Schenker::ModPerl
  require 'any/moose'
  %x{
  BEGIN {
    extends 'HTTP::Engine::Interface::ModPerl';
    Schenker::init;
  }
  }
  def create_engine
    :'$Schenker::Engine'
  end
  %x'no Any::Moose;'
  self.meta.make_immutable
end
