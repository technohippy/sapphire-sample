class Schenker::Halt < Exporter
  require 'any/moose'
  %x{
  use overload
      '""'   => \\&as_string,
      'bool' => sub { 1 };
  }

  @@EXPORT = %w(halt)

  has 'status', [
    'is', 'ro',
    'isa', 'Int'
  ]

  has 'message', [
    'is', 'ro',
    'isa', 'Str'
  ]

  def BUILDARGS(*args)
    options = nil
    if args.size == 1
      options['message'] = args[0]
    elsif args.size == 2
      options['status'] = args[0]
      options['message'] = args[1]
    end
    options
  end

  def halt(__no_self__)
    die self.class.new(@_)
  end

  def as_string
    self.message
  end

  %x'no Any::Moose;'
  self.meta.make_immutable
end

