class Schenker::ModPerl
  require 'any/moose'
  __BEGIN__ do
    extend HTTP::Engine::Interface::ModPerl
    Schenker.init
  end 

  def create_engine
    :'$Schenker::Engine'
  end
  %x'no Any::Moose;'
  self.meta.make_immutable
end
