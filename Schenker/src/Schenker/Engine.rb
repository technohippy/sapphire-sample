class Schenker::Engine < Exporter
  require 'any/moose'
  require 'carp', %w(croak)
  require 'h_t_t_p/engine'
  require 'h_t_t_p/engine/middleware'
  require 'schenker/options'

  @@EXPORT = %w(Use)

  engine = nil
  middleware = nil

  def engine
    :$engine # TODO
  end

  def middleware
    middleware ||= HTTP::Engine::Middleware.new 'method_class', 'HTTP::Engine::Request'
  end

  def Use(__no_self__)
    croak 'module required' if @_.empty?
    middleware.install @_
  end

  def install_builtin_middlewares
    configure 'development', ->{
      Use 'HTTP::Engine::Middleware::AccessLog', {
          'logger' => ->{ :'print STDERR @_, "\\n"' }
      } if standalone
    }

    Use 'HTTP::Engine::Middleware::Static', {
      'regexp' => %r{^/(.*)$},
      'docroot' => options.public,
      'is_404_handler' => 0
    } if options.static
    Use 'HTTP::Engine::Middleware::MethodOverride' if options.methodoverride
    Use 'HTTP::Engine::Middleware::Encode', options.encode
    Use 'HTTP::Engine::Middleware::HTTPSession', options.session_options if options.sessions
  end

  def init_signal
    return unless standalone
    SIG[:INT] = SIG[:QUIT] = SIG[:TERM] = ->{
      STDERR.print "\n== Schenker has ended his set (crowd applauds)\n"
      exit
    }
  end

  def print_banner
    return unless standalone;
    STDERR.print "== Schenker/$Schenker::VERSION has taken the stage on @{[options->port]} for @{[options->environment]} with backup from @{[options->server]}\n";
  end

  def init(handler)
    croak 'handler required' unless handler

    install_builtin_middlewares
    init_signal

    args = {}
    if standalone
      args['host'] = options.host
      args['port'] = options.port
    elsif options.server == 'FCGI'
      args['listen'] = options.listen if defined options.listen
      args['nproc'] = options.nproc if defined options.nproc
      args['pidfile'] = options.pidfile if defined options.pidfile
      args['detach'] = options.detach if defined options.detach
      args['manager'] = options.manager if defined options.manager
      args['keep_stderr'] = options.keeperr if defined options.keeperr
    end

    engine = HTTP::Engine.new(
      'interface', {
        'module' => options.server,
        'args' => args,
        'request_handler' => middleware.handler(handler)
      }
    )
  end

  def run(*args)
    print_banner
    res = engine.run args
    POE::Kernel.run if options.server == 'POE'
    AnyEvent.condvar.recv if options.server == 'AnyEvent'
    res
  end

  no Any::Moose
  self.meta.make_immutable
end
