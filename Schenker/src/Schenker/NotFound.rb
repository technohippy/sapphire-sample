class Schenker::NotFound
  include Any::Moose

  __BEGIN__ do
    extends Schenker::Error
  end

  no Any::Moose
  self.meta.make_immutable
end
