class Schenker::Error
  require 'any/moose'
  %x{
  use overload
      '""'   => \\&as_string,
      'bool' => sub { 1 };
  }
  require 'c_g_i/exception_manager/stack_trace'

  has 'message', [
    'is', 'ro',
    'isa', 'Str'
  ]

  has 'stack_trace', [
    'is', 'ro',
    'isa', 'CGI::ExceptionManager::StackTrace'
  ]

  def BUILDARGS(message)
    if message
      message = message.to_s
    else
      message = ''
    end
    stack_trace = CGI::ExceptionManager::StackTrace.new message
    { :message => message, :stack_trace => stack_trace }
  end

  def raise
    this = nil
    if ref(self)
      this = self
    else
      this = self.new @_
    end
    die this
  end

  def as_string
    self.message
  end

  %x'no Any::Moose;'
  self.meta.make_immutable
end
