class Schenker::ModPerl
  include Any::Moose

  __BEGIN__ do
    extend HTTP::Engine::Interface::ModPerl
    Schenker.init
  end 

  def create_engine
    :'$Schenker::Engine'
  end

  no Any::Moose
  self.meta.make_immutable
end
