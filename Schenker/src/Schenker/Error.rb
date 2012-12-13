class Schenker::Error
  include Any::Moose
  use overload(
      '""', :'\\&as_string',
      'bool', ->{1}
  )
  include CGI::ExceptionManager::StackTrace

  has 'message', [
    'is', 'ro',
    'isa', 'Str'
  ]

  has 'stack_trace', [
    'is', 'ro',
    'isa', 'CGI::ExceptionManager::StackTrace'
  ]

  def BUILDARGS(message)
    message = message ? message.to_s : ''
    stack_trace = CGI::ExceptionManager::StackTrace.new message
    { :message => message, :stack_trace => stack_trace }
  end

  def raise
    this = ref(self) ? self : self.new(@_)
    die this
  end

  def as_string
    self.message
  end

  no Any::Moose
  self.meta.make_immutable
end
